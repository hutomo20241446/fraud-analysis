use pbl_paper_id;

select count(*) from transaction_frequency_metrics;

/*------------------------------------  SQL View --------------------------------------------*/
-- 1.1 Membuat view untuk pasangan pembeli-penjual yang paling mencurigakan berdasarkan fitur baru
-- burst_activity, unusual_gap, burst_amount dibuat pada tahap feature engineering di task 2
-- Pasangan buyer-seller paling mencurigakan
CREATE VIEW Suspicious_Buyer_Seller_Pairs AS
SELECT
    buyer_id,
    seller_id,
    COUNT(dpt_id) AS suspicious_transaction_freq,
    ROUND(SUM(transaction_amount)) AS total_transaction_amount
FROM
    transaction_frequency_metrics
WHERE
    (burst_activity = 1 AND burst_amount = 1) 
    OR (unusual_gap = 1 AND burst_amount = 1) 
GROUP BY
    buyer_id,
    seller_id
ORDER BY
    suspicious_transaction_freq DESC; 
   
select * from Suspicious_Buyer_Seller_Pairs;
    

-- 1.2 Membuat View untuk pengguna yang terindikasi fraud atau di-blacklist dan transaksi mereka
-- Pengguna yang ditandai dan transaksi mereka
CREATE VIEW Flagged_Users_Transactions AS
SELECT
    t.dpt_id AS ID_Transaksi,
    t.buyer_id AS ID_Pembeli,
    t.seller_id AS ID_Penjual,
    t.transaction_amount AS Jumlah_Transaksi,
    t.payment_method_name AS Metode_Pembayaran,
    t.payment_provider_name AS Penyedia_Pembayaran,
    t.transaction_created_datetime AS Waktu_Transaksi,
    t.dpt_promotion_id AS ID_Promosi,
    ub.user_fraud_flag AS Flag_Fraud_Pembeli,
    ub.blacklist_account_flag AS Flag_Blacklist_Pembeli,
    us.user_fraud_flag AS Flag_Fraud_Penjual,
    us.blacklist_account_flag AS Flag_Blacklist_Penjual,
    CASE 
        WHEN t.buyer_id = t.seller_id THEN 1
        ELSE 0
    END AS Flag_Self_Transaction

FROM
    transaction t
LEFT JOIN
    user ub
ON
    t.buyer_id = ub.company_id
LEFT JOIN
    user us
ON
    t.seller_id = us.company_id
WHERE
    (ub.user_fraud_flag = 1 OR ub.blacklist_account_flag = 1)
    OR
    (us.user_fraud_flag = 1 OR us.blacklist_account_flag = 1);

   
select count(*) from flagged_users_transactions;

select * from flagged_users_transactions;
