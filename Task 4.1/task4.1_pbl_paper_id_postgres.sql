
-- 4.1.a Transaction Anomalies: Transactions with values far outside the normal range for each buyer/seller pair.
-- Transaksi Jauh di Luar Rentang Normal
WITH BuyerSellerStats AS (
    SELECT 
        buyer_id,
        seller_id,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY transaction_amount) AS Q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY transaction_amount) AS Q3
    FROM transaction
    GROUP BY buyer_id, seller_id
),
IQRCalculation AS (
    SELECT 
        bss.buyer_id,
        bss.seller_id,
        bss.Q1,
        bss.Q3,
        (bss.Q3 - bss.Q1) AS IQR,
        GREATEST(0, ROUND((bss.Q1 - 1.5 * (bss.Q3 - bss.Q1)))) AS lower_bound,
        ROUND((bss.Q3 + 1.5 * (bss.Q3 - bss.Q1))) AS upper_bound
    FROM BuyerSellerStats bss
),
Anomalies AS (
    SELECT 
        t.buyer_id,
        t.seller_id,
        t.transaction_amount,
        ic.lower_bound,
        ic.upper_bound
    FROM transaction t
    JOIN IQRCalculation ic 
        ON t.buyer_id = ic.buyer_id AND t.seller_id = ic.seller_id
    WHERE t.transaction_amount < ic.lower_bound 
       OR t.transaction_amount > ic.upper_bound
)

SELECT 
    buyer_id,
    seller_id,
    transaction_amount,
    lower_bound,
    upper_bound
FROM Anomalies
ORDER BY buyer_id, seller_id, transaction_amount;

select count(*) from Anomalies;


-- 4.1.b Buyer-Seller Relationship Analysis: buyer-seller pairs with unusually high transaction frequencies or amounts
-- Analisis Hubungan Pembeli-Penjual
WITH Buyer_Seller_Stats AS (
    SELECT 
        t.buyer_id,
        t.seller_id,
        COUNT(t.dpt_id) AS frekuensi_transaksi,
        MAX(t.transaction_amount) AS transaksi_terbesar,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY t.transaction_amount) AS Q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY t.transaction_amount) AS Q3
    FROM 
        transaction t
    GROUP BY 
        t.buyer_id, t.seller_id
),
IQR_Calculations AS (
    SELECT 
        bss.buyer_id,
        bss.seller_id,
        bss.frekuensi_transaksi,
        bss.transaksi_terbesar,
        bss.Q1,
        bss.Q3,
        (bss.Q3 - bss.Q1) AS IQR,
        (bss.Q3 + 1.5 * (bss.Q3 - bss.Q1)) AS upper_bound
    FROM 
        Buyer_Seller_Stats bss
),
Anomalies AS (
    SELECT 
        ic.buyer_id,
        ic.seller_id,
        ic.frekuensi_transaksi,
        ic.transaksi_terbesar,
        ic.upper_bound,
        COUNT(CASE WHEN t.transaction_amount > ic.upper_bound THEN 1 END) AS count_above_upperbound
    FROM 
        transaction t
    JOIN 
        IQR_Calculations ic 
        ON t.buyer_id = ic.buyer_id AND t.seller_id = ic.seller_id
    GROUP BY 
        ic.buyer_id, ic.seller_id, ic.frekuensi_transaksi, ic.transaksi_terbesar, ic.upper_bound
),
Final_Output AS (
    SELECT 
        a.*,
        CASE WHEN a.buyer_id = a.seller_id THEN 1 ELSE 0 END AS is_self_transaction,
        bu.user_fraud_flag AS buyer_fraud_flag,
        bu.blacklist_account_flag AS buyer_blacklist_flag,
        su.user_fraud_flag AS seller_fraud_flag,
        su.blacklist_account_flag AS seller_blacklist_flag
    FROM 
        Anomalies a
    LEFT JOIN 
        users bu ON a.buyer_id = bu.company_id
    LEFT JOIN 
        users su ON a.seller_id = su.company_id
)
SELECT 
    buyer_id,
    seller_id,
    is_self_transaction,
    frekuensi_transaksi,
    ROUND(transaksi_terbesar) AS transaksi_terbesar,
    ROUND(upper_bound) AS upper_bound,
    count_above_upperbound
--    buyer_fraud_flag,
--    buyer_blacklist_flag,
--    seller_fraud_flag,
--    seller_blacklist_flag
FROM 
    Final_Output
ORDER BY 
    frekuensi_transaksi DESC, transaksi_terbesar DESC;
      
   
-- Promotion Misuse Detection: Users excessively used promotions within a short period of time
-- Deteksi Penyalahgunaan Promosi   
WITH Filtered_Transactions AS (
    SELECT 
        buyer_id,
        seller_id,
        dpt_promotion_id,
        transaction_created_datetime::timestamp AS created_at
    FROM 
        transaction
    WHERE 
        dpt_promotion_id <> 'no promotion'
),
Ranked_Transactions AS (
    SELECT 
        buyer_id,
        seller_id,
        dpt_promotion_id,
        created_at,
        ROW_NUMBER() OVER (
            PARTITION BY buyer_id, seller_id, dpt_promotion_id 
            ORDER BY created_at
        ) AS rank,
        COUNT(*) OVER (PARTITION BY buyer_id, seller_id, dpt_promotion_id) AS count_promotion_usage
    FROM 
        Filtered_Transactions
),
Duration_Calculation AS (
    SELECT 
        buyer_id,
        seller_id,
        dpt_promotion_id,
        COUNT(*) AS count_promotion_usage,
        MIN(created_at) AS first_usage,
        MAX(created_at) AS last_usage,
        EXTRACT(DAY FROM (MAX(created_at) - MIN(created_at))) AS duration
    FROM 
        Ranked_Transactions
    GROUP BY 
        buyer_id, seller_id, dpt_promotion_id
)
SELECT 
    buyer_id,
    seller_id,
    dpt_promotion_id,
    count_promotion_usage,
    duration
FROM 
    Duration_Calculation
where
	(count_promotion_usage >= 3) and (duration <= 30)
ORDER BY 
    count_promotion_usage DESC, duration DESC;


   
--●	Suspicious Timing: Transactions at irregular hours or intervals (e.g., many transactions in a short time span).
-- waktu yang mencurigakan


WITH Transaction_1Hour AS (
    SELECT
        DATE(transaction_created_datetime::timestamp) AS transaction_date,
        DATE_TRUNC('hour', transaction_created_datetime::timestamp) 
        + INTERVAL '1 hour' * FLOOR(EXTRACT(MINUTE FROM transaction_created_datetime::timestamp) / 60) AS transaction_1hour_start,
        COUNT(*) AS transaction_frequency
    FROM
        transaction
    WHERE 
        EXTRACT(HOUR FROM transaction_created_datetime::timestamp) NOT BETWEEN 9 AND 16
    GROUP BY
        DATE(transaction_created_datetime::timestamp),
        DATE_TRUNC('hour', transaction_created_datetime::timestamp) 
        + INTERVAL '1 hour' * FLOOR(EXTRACT(MINUTE FROM transaction_created_datetime::timestamp) / 60)
),
Formatted_1Hour AS (
    SELECT
        transaction_date,
        TO_CHAR(transaction_1hour_start, 'HH24:MI') || ' - ' || 
        TO_CHAR(transaction_1hour_start + INTERVAL '1 hour', 'HH24:MI') AS time_range,
        transaction_frequency
    FROM
        Transaction_1Hour
    where transaction_frequency >= 12
)
--SELECT 
--    transaction_date AS datetime,
--    time_range AS "time range",
--    transaction_frequency
--FROM 
--    Formatted_1Hour
--ORDER BY 
--    /*datetime, "time range",*/ transaction_frequency DESC;

   
select 
	time_range, 
	round(avg(transaction_frequency)) avg_daily_transaction_frequency
from Formatted_1Hour
group by time_range
order by avg_daily_transaction_frequency desc;

   
------------------------------------ Flagged User Connections 1---------------------------------------------
WITH Flagged_Users AS (
    SELECT 
        company_id,
        user_fraud_flag,
        blacklist_account_flag
    FROM 
        users
    WHERE 
        user_fraud_flag = 1 OR blacklist_account_flag = 1
),
User_Connections AS (
    SELECT 
        ft.dpt_id,
        ft.buyer_id,
        ft.seller_id,
        fu_buyer.user_fraud_flag AS buyer_fraud_flag,
        fu_buyer.blacklist_account_flag AS buyer_blacklist_flag,
        fu_seller.user_fraud_flag AS seller_fraud_flag,
        fu_seller.blacklist_account_flag AS seller_blacklist_flag,
        ft.transaction_amount,
        ft.transaction_created_datetime::timestamp AS transaction_time
    FROM 
        transaction ft
    LEFT JOIN 
        users fu_buyer ON ft.buyer_id = fu_buyer.company_id
    LEFT JOIN 
        users fu_seller ON ft.seller_id = fu_seller.company_id
    WHERE 
        fu_buyer.user_fraud_flag = 1 OR 
        fu_buyer.blacklist_account_flag = 1 OR 
        fu_seller.user_fraud_flag = 1 OR 
        fu_seller.blacklist_account_flag = 1
),
Flagged_Transactions AS (
    SELECT 
        buyer_id,
        seller_id,
        CASE WHEN buyer_id = seller_id THEN 1 ELSE 0 END AS is_self_transaction,
        COUNT(*) AS total_transactions,
        SUM(transaction_amount) AS total_amount,
        MIN(transaction_time) AS first_transaction,
        MAX(transaction_time) AS last_transaction,
        DATE_PART('day', MAX(transaction_time) - MIN(transaction_time)) AS first_to_last_transaction_days,
        MAX(buyer_fraud_flag) AS buyer_fraud_flag,
        MAX(buyer_blacklist_flag) AS buyer_blacklist_flag,
        MAX(seller_fraud_flag) AS seller_fraud_flag,
        MAX(seller_blacklist_flag) AS seller_blacklist_flag
    FROM 
        User_Connections
    GROUP BY 
        buyer_id, seller_id
)
SELECT 
    buyer_id,
    seller_id,
    is_self_transaction,
    total_transactions,
    total_amount,
    first_transaction,
    last_transaction,
    first_to_last_transaction_days,
    buyer_fraud_flag,
    buyer_blacklist_flag,
    seller_fraud_flag,
    seller_blacklist_flag
FROM 
    Flagged_Transactions
ORDER BY 
    total_transactions DESC, total_amount DESC;


-- 
