USE world_stocks;

SET autocommit = 0;

ALTER TABLE stocks
	RENAME COLUMN `Capital Gains` TO `Capital_Gains`,
	RENAME COLUMN `Stock Splits` TO `Stock_Splits`,
	RENAME COLUMN `Date` TO `Date_time`;
    
    
DELIMITER $$
CREATE DEFINER=`root`@`localhost` FUNCTION `CapitalizeWords`(words VARCHAR(30)) RETURNS varchar(30) CHARSET utf8mb4
    DETERMINISTIC
BEGIN
	DECLARE i INT DEFAULT 1;
    DECLARE word_length INT;
    SET word_length = CHAR_LENGTH(words);
    
    WHILE i <= word_length DO
		IF i = 1 OR SUBSTR(words, i-1, 1) = ' ' THEN
			SET words = CONCAT(LEFT(words, i -1 ),
								UCASE(SUBSTR(words, i,1)),
								LCASE(SUBSTR(words, i+1))
                                );
		END IF;
		SET i = i + 1;
	END WHILE;

	RETURN words;
END$$
DELIMITER ;

SET SQL_SAFE_UPDATES = 0;

UPDATE stocks
SET Country = CapitalizeWords(Country);

UPDATE stocks
SET Brand_Name = CapitalizeWords(Brand_Name);

UPDATE stocks
SET Industry_Tag = CapitalizeWords(Industry_Tag);
	
SET SQL_SAFE_UPDATES = 1;
-- General Stock Performance:
-- How has a specific stock's closing price changed over time?
SELECT Date_time, Close FROM stocks
WHERE Brand_Name = 'Toyota' 
ORDER BY Date_time;

-- What are the highest and lowest prices for a given stock over the last month, quarter, or year?
SELECT Brand_Name, Month(Date_time), Max(High), min(Low) FROM stocks
WHERE Brand_Name = 'Block'
GROUP BY 1,2
ORDER BY Month(Date_time);

select Brand_Name, Quarter(Date_time), Max(High), min(Low) FROM stocks
WHERE Brand_Name = 'Block'
GROUP BY 1,2
ORDER BY Quarter(Date_time);

-- How do stocks’ daily volatility compare to its annual volatility?
WITH log_returns AS (
	SELECT Brand_Name, Date_time,
    log(Close / Lag(Close) OVER( PARTITION BY Brand_Name ORDER BY Date_time)) AS log_return
    FROM stocks
)
select Brand_Name, 
	STDDEV(log_return) as daily_volatility,
    STDDEV(log_return) * SQRT(6341) AS annual_volatility
-- 6341 is the number of distinct dates in this dataset
FROM log_returns 
WHERE log_return IS NOT NULL
GROUP BY 1;

-- Comparing Stocks & Sectors:
-- How does one stock’s performance compare to others in the same industry?
WITH stock_performance AS (
	SELECT Brand_Name, Industry_Tag,
    (( Close / first_value(Close) OVER(ORDER BY Date_time)) - 1)*100 AS cumulative_return,
    ((High - Low)/Open) * 100 AS daily_volatility,
    Volume
    FROM stocks
    WHERE Industry_Tag = 'Apparel'
),
	industry_average as(
	SELECT Industry_Tag,
		AVG(cumulative_return) AS avg_industry_return,
		AVG(daily_volatility) AS avg_industry_volatility
	FROM stock_performance
    GROUP BY 1
)
SELECT sp.Brand_Name, sp.cumulative_return, sp.daily_volatility,
	ia.avg_industry_return, ia.avg_industry_volatility, sp.Volume
    FROM stock_performance sp
    JOIN industry_average ia
    ON sp.Brand_Name IS NOT NULL
    ORDER BY sp.Volume DESC;
		
-- Moving Average
SELECT s1.Date_time, s1.tickers,
       AVG(s2.close) AS moving_avg
FROM stocks s1
JOIN stocks s2 ON s1.tickers = s2.tickers 
     AND s2.datetime BETWEEN DATE_SUB(s1.Date_time, INTERVAL 4 DAY) AND s1.datetime
GROUP BY 1,2;

-- Which country’s stocks have the highest average volume over the last year?
SELECT Country, 
       AVG(volume) 
FROM stock_data
WHERE Year(Date_time) = 2025
GROUP BY Country
ORDER BY AVG(volume)  DESC
LIMIT 1;

