use pbl_paper_id;


-- Membuat edge_list untuk social network analisis user yang terlibat transaksi fraud    
WITH transaction_with_buyer_flags AS (
    SELECT 
        t.*,
        u.user_fraud_flag AS user_fraud_flag_buyer,
        u.blacklist_account_flag AS blacklist_account_flag_buyer
    FROM transaction t
    LEFT JOIN user u
        ON t.buyer_id = u.company_id
),
transaction_with_seller_flags AS (
    SELECT 
        tb.*,
        COALESCE(us.user_fraud_flag, 1) AS user_fraud_flag_seller,
        COALESCE(us.blacklist_account_flag, 1) AS blacklist_account_flag_seller
    FROM transaction_with_buyer_flags tb
    LEFT JOIN user us
        ON tb.seller_id = us.company_id
),
filtered_transactions AS (
    SELECT *
    FROM transaction_with_seller_flags
    WHERE 
        user_fraud_flag_buyer = 1 OR
        blacklist_account_flag_buyer = 1 OR
        user_fraud_flag_seller = 1 OR
        blacklist_account_flag_seller = 1
),
final_filtered_transactions AS (
    SELECT *
    FROM filtered_transactions
    WHERE buyer_id != seller_id
)
SELECT buyer_id, seller_id
FROM final_filtered_transactions;

   