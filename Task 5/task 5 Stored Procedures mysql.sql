use pbl_paper_id;

/*------------------------------------------SQL Stored Procedures-------------------------------------*/

-- 2.1 Monthly Fraud Report Procedure
-- laporan penipuan bulanan
DELIMITER $$

CREATE PROCEDURE MonthlyFraudReport(IN report_month VARCHAR(7))
BEGIN
    DECLARE total_fraud_amount DOUBLE;
    DECLARE total_fraud_user_count INT;
    DECLARE total_suspicious_count INT;
    DECLARE total_fraud_transaction_count INT;

    -- Hitung Total Fraud Amount
    SELECT 
        SUM(tfm.transaction_amount)
    INTO total_fraud_amount
    FROM transaction_frequency_metrics tfm
    LEFT JOIN user u_buyer ON tfm.buyer_id = u_buyer.company_id
    LEFT JOIN user u_seller ON tfm.seller_id = u_seller.company_id
    WHERE 
        (u_buyer.user_fraud_flag = 1 OR u_seller.user_fraud_flag = 1)
        AND DATE_FORMAT(tfm.transaction_created_datetime, '%Y-%m') = report_month;

    -- Hitung Total Fraud Users
    SELECT 
        COUNT(DISTINCT CASE WHEN u_buyer.user_fraud_flag = 1 THEN tfm.buyer_id END) 
        + COUNT(DISTINCT CASE WHEN u_seller.user_fraud_flag = 1 THEN tfm.seller_id END)
    INTO total_fraud_user_count
    FROM transaction_frequency_metrics tfm
    LEFT JOIN user u_buyer ON tfm.buyer_id = u_buyer.company_id
    LEFT JOIN user u_seller ON tfm.seller_id = u_seller.company_id
    WHERE 
        (u_buyer.user_fraud_flag = 1 OR u_seller.user_fraud_flag = 1)
        AND DATE_FORMAT(tfm.transaction_created_datetime, '%Y-%m') = report_month;

    -- Hitung Total Fraud Transactions (Buyer-Seller Pairs)
    SELECT 
        COUNT(DISTINCT CONCAT(tfm.buyer_id, '-', tfm.seller_id))
    INTO total_fraud_transaction_count
    FROM transaction_frequency_metrics tfm
    LEFT JOIN user u_buyer ON tfm.buyer_id = u_buyer.company_id
    LEFT JOIN user u_seller ON tfm.seller_id = u_seller.company_id
    WHERE 
        (u_buyer.user_fraud_flag = 1 OR u_seller.user_fraud_flag = 1)
        AND DATE_FORMAT(tfm.transaction_created_datetime, '%Y-%m') = report_month;

    -- Hitung Total Suspicious Buyer-Seller Pairs
    SELECT 
        COUNT(DISTINCT CONCAT(tfm.buyer_id, '-', tfm.seller_id))
    INTO total_suspicious_count
    FROM transaction_frequency_metrics tfm
    WHERE 
        ((tfm.burst_activity = 1 AND tfm.burst_amount = 1)
        OR (tfm.unusual_gap = 1 AND tfm.burst_amount = 1))
        AND DATE_FORMAT(tfm.transaction_created_datetime, '%Y-%m') = report_month
        AND CONCAT(tfm.buyer_id, '-', tfm.seller_id) NOT IN (
            SELECT DISTINCT CONCAT(f_tfm.buyer_id, '-', f_tfm.seller_id)
            FROM transaction_frequency_metrics f_tfm
            LEFT JOIN user f_u_buyer ON f_tfm.buyer_id = f_u_buyer.company_id
            LEFT JOIN user f_u_seller ON f_tfm.seller_id = f_u_seller.company_id
            WHERE 
                (f_u_buyer.user_fraud_flag = 1 OR f_u_seller.user_fraud_flag = 1)
                AND DATE_FORMAT(f_tfm.transaction_created_datetime, '%Y-%m') = report_month
        );

    -- Hasil Akhir
    SELECT 
        CAST(total_fraud_amount AS UNSIGNED) AS fraud_transaction_amounts,
        total_fraud_user_count AS fraud_users,
        total_fraud_transaction_count AS fraud_transactions,
        total_suspicious_count AS suspicious_buyer_seller_pairs;
END $$

DELIMITER ;


CALL MonthlyFraudReport('2023-03');


-- 2.2 Automated Promotion Misuse Detection
-- Deteksi penyalahgunaan otomatis
DELIMITER //

CREATE PROCEDURE PromoMisuseDetection()
BEGIN
    -- Hapus tabel sementara jika sudah ada
    DROP TEMPORARY TABLE IF EXISTS temp_promo_transactions;
    DROP TEMPORARY TABLE IF EXISTS promo_counts;

    -- Tabel sementara untuk menyimpan data transaksi dengan lag calculation
    CREATE TEMPORARY TABLE temp_promo_transactions AS
    SELECT
        buyer_id,
        dpt_promotion_id,
        transaction_created_datetime,
        -- Penanda transaksi sebelumnya
        LAG(transaction_created_datetime) OVER (PARTITION BY buyer_id, dpt_promotion_id ORDER BY transaction_created_datetime) AS prev_transaction_datetime
    FROM transaction
    WHERE 
        dpt_promotion_id IS NOT NULL
        AND dpt_promotion_id <> 'no promotion'; -- Mengabaikan transaksi tanpa promosi

    -- Variabel untuk menghitung consecutive promo count
    SET @row_num := 0;
    SET @prev_buyer := NULL;
    SET @prev_promo := NULL;

    -- Tabel sementara kedua untuk menghitung consecutive promo count
    CREATE TEMPORARY TABLE promo_counts AS
    SELECT
        buyer_id,
        dpt_promotion_id,
        transaction_created_datetime,
        -- Menghitung transaksi berturut-turut
        @row_num := IF(@prev_buyer = buyer_id AND @prev_promo = dpt_promotion_id, @row_num + 1, 1) AS consecutive_promo_count,
        @prev_buyer := buyer_id,
        @prev_promo := dpt_promotion_id
    FROM temp_promo_transactions
    ORDER BY buyer_id, dpt_promotion_id, transaction_created_datetime;

    -- Tampilkan data misuse ke output jika melebihi threshold
    SELECT 
        buyer_id,
        dpt_promotion_id,
        MAX(consecutive_promo_count) AS consecutive_count,
        DATEDIFF(MAX(transaction_created_datetime), MIN(transaction_created_datetime)) AS transaction_duration_days,
        'Penggunaan promosi berulang melebihi ambang batas' AS misuse_reason
    FROM promo_counts
    GROUP BY buyer_id, dpt_promotion_id
    HAVING MAX(consecutive_promo_count) >= 3  -- Ambang batas deteksi
    ORDER BY consecutive_count DESC, transaction_duration_days ASC;
    
END //

DELIMITER ;




-- Menjalankan Stored Procedure
CALL PromoMisuseDetection();

select* from log_promosi_misuse;