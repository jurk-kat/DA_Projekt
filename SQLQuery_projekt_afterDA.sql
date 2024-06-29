-----------------------------------------------
-- DateTime correction - some of the datestamps contained minutes, which should be only hours.
-----------------------------------------------

UPDATE harbour
SET DateTime = CAST(
                    CONCAT(
                        LEFT(CONVERT(varchar(32), DateTime, 121), 14),  -- yyyy-mm-dd hh:
                        '00',                                          -- nastavíme minuty na '00'
                        SUBSTRING(CONVERT(varchar(32), DateTime, 121), 17, 12)  -- zbývající část
                    ) AS datetime2
                )
WHERE SUBSTRING(CONVERT(varchar(32), DateTime, 121), 15, 2) <> '00'
;

-----------------------------------------------
-- Kolik bylo ve kterou hodinu v pristavu celkem lidi?
-----------------------------------------------

SELECT
    DateTime,
    SUM(passengers) AS passengers_sum
FROM
    harbour
GROUP BY
    DateTime
ORDER BY passengers_sum ASC
;

-----------------------------------------------
-- v jake casove intervaly bylo v pristavu kolik lidi?
-- cilem je ziskat interval od-do a pocet lidu v pristavu, ktere budeme moci zobrazit v grafu.
-----------------------------------------------

WITH t_sum AS
(
    SELECT
        DateTime,
        SUM(passengers) AS passengers_sum
    FROM
        harbour
    GROUP BY
        DateTime
)
,
t_podminka AS
(
    SELECT 
        DateTime,
        passengers_sum,
        LAG(passengers_sum) OVER (ORDER BY DateTime) AS prev_passengers_sum
    FROM 
        t_sum
)
,
change_points AS
(
    SELECT 
        DateTime,
        passengers_sum,
        CASE 
            WHEN passengers_sum = prev_passengers_sum THEN 0
            ELSE 1
        END AS change_flag
    FROM 
        t_podminka
)
,
grouped_intervals AS
(
    SELECT 
        DateTime,
        passengers_sum,
        SUM(change_flag) OVER (ORDER BY DateTime) AS change_group
    FROM 
        change_points
)
SELECT 
    MIN(DateTime) AS interval_start,
    MAX(DateTime) AS interval_end,
    passengers_sum
FROM 
    grouped_intervals
GROUP BY 
    passengers_sum, change_group
ORDER BY 
    passengers_sum DESC
;

-----------------------------------------------
-- Jaka cast pasazeru v pristavu pochazela ze ktere lode v kazdou hodinu?
-- A jake narodnosti?
-----------------------------------------------

WITH t_sum AS
(
    SELECT
        DateTime,
        SUM(passengers) AS passengers_sum
    FROM
        harbour
    GROUP BY
        DateTime
)
SELECT
    t.DateTime,
    t.passengers_sum,
    h.boat,
    n.nationality,
    h.passengers,
    h.agent,
    ROUND((h.passengers*1.00)/(t.passengers_sum*1.00)*100, 1) AS passengers_percentage
FROM
    harbour AS h
JOIN t_sum AS t ON h.DateTime = t.DateTime
JOIN nationalities AS n ON h.boat = n.boat
;


----------------------------------------------------------------------------------------------
-- kolik procent z celku jednotlivych produktu zkoupi ktera narodnost?
-- zajima nas, kolik za co ktera narodnost utrati, kolik kusu ceho koupi a kolik je to procent z celkoveho revenue a celkoveho poctu za dany artikl
-- OPRAVA predpisu z projektu. Zde je zohledneno to, ze revenue je treba rozdelit mezi jednotlive lode, ne nakopirovat a 'zmnozit'. Pro jednoduchost nyni uvazuji, ze vsichni nakupuji na osobu stejne
----------------------------------------------------------------------------------------------

WITH t_sum AS
(
    SELECT
        DateTime,
        SUM(passengers) AS passengers_sum
    FROM
        harbour
    GROUP BY
        DateTime
),
adjusted_harbour AS
(
    SELECT
        t.DateTime,
        t.passengers_sum,
        h.boat,
        h.passengers,
        h.agent,
        ROUND((h.passengers * 1.00) / (t.passengers_sum * 1.00) * 100, 1) AS passengers_percentage
    FROM
        harbour AS h
    JOIN t_sum AS t ON h.DateTime = t.DateTime
),
kombi_tabulka AS
(
    SELECT
        a.DateTime,
        a.passengers_sum,
        n.nationality,
        a.boat,
        a.passengers,
        a.agent,
        a.passengers_percentage,
        s.product,
        d.EN,
        ROUND(s.units / 100.0 * a.passengers_percentage, 0) AS units_adjusted,
        ROUND(s.total_price / 100.0 * a.passengers_percentage, 0) AS total_price_adjusted
    FROM 
        sales s
    JOIN adjusted_harbour a ON s.DateTime = a.DateTime
    JOIN nationalities n ON a.boat = n.boat
    JOIN dictionary d ON s.product = d.product
),
product_totals AS
(
    SELECT
        d.EN,
        SUM(s.total_price) AS total_revenue_product,
        SUM(s.units) AS total_units_product
    FROM 
        sales s
    JOIN dictionary d ON s.product = d.product
    GROUP BY
        d.EN
)
SELECT
    k.EN,
    k.nationality,
    ROUND(SUM(k.total_price_adjusted), 0) AS total_revenue,
    SUM(k.units_adjusted) AS total_units_sold,
    ROUND((SUM(k.total_price_adjusted) * 100.0 / pt.total_revenue_product), 1) AS revenue_percentage,
    ROUND((SUM(k.units_adjusted) * 100.0 / pt.total_units_product), 1) AS units_percentage
FROM 
    kombi_tabulka k
JOIN product_totals pt ON k.EN = pt.EN
GROUP BY
    k.EN,
    k.nationality,
    pt.total_revenue_product,
    pt.total_units_product
ORDER BY
    k.EN,
    k.nationality
;


----------------------------------------------------------------------------------------------
-- Co ktera narodnost procentuelne nakupuje?
-- divame se z pohledu narodnosti a co kupuji, ne z pohledu kolik procent ceho ktera narodnost koupi. Lepe zohlednuje fakt, ze narosnosti nemaji v obchode stejne zastoupeni.
-- OPRAVA predpisu z projektu. Zde je zohledneno to, ze revenue je treba rozdelit mezi jednotlive lode, ne nakopirovat a 'zmnozit'. Pro jednoduchost nyni uvazuji, ze vsichni nakupuji na osobu stejne
----------------------------------------------------------------------------------------------
WITH t_sum AS
(
    SELECT
        DateTime,
        SUM(passengers) AS passengers_sum
    FROM
        harbour
    GROUP BY
        DateTime
),
adjusted_harbour AS
(
    SELECT
        t.DateTime,
        t.passengers_sum,
        h.boat,
        h.passengers,
        h.agent,
        ROUND((h.passengers * 1.00) / (t.passengers_sum * 1.00) * 100, 1) AS passengers_percentage
    FROM
        harbour AS h
    JOIN t_sum AS t ON h.DateTime = t.DateTime
),
kombi_tabulka AS
(
    SELECT
        a.DateTime,
        a.passengers_sum,
        n.nationality,
        a.boat,
        a.passengers,
        a.agent,
        a.passengers_percentage,
        s.product,
        d.EN,
        ROUND(s.units / 100.0 * a.passengers_percentage, 0) AS units_adjusted,
        ROUND(s.total_price / 100.0 * a.passengers_percentage, 0) AS total_price_adjusted
    FROM 
        sales s
    JOIN adjusted_harbour a ON s.DateTime = a.DateTime
    JOIN nationalities n ON a.boat = n.boat
    JOIN dictionary d ON s.product = d.product
),
total_revenue AS
(
    SELECT
        nationality,
        SUM(total_price_adjusted) AS total_revenue,
        SUM(units_adjusted) AS total_units
    FROM 
        kombi_tabulka
    GROUP BY 
        nationality
),
revenue_by_product AS
(
    SELECT
        nationality,
        EN,
        SUM(total_price_adjusted) AS product_revenue,
        SUM(units_adjusted) AS product_units
    FROM 
        kombi_tabulka
    GROUP BY 
        nationality, EN
)
SELECT
    r.nationality,
    r.EN,
    ROUND(r.product_revenue, 0) AS product_revenue,
    ROUND(t.total_revenue, 0) AS total_revenue,
    ROUND((r.product_revenue * 100.0 / t.total_revenue), 2) AS percentage_of_total_revenue,
    r.product_units,
    t.total_units,
    ROUND((r.product_units * 100.0 / t.total_units), 2) AS percentage_of_total_units
FROM 
    revenue_by_product r
JOIN total_revenue t ON r.nationality = t.nationality
ORDER BY 
    r.nationality,
    percentage_of_total_revenue DESC
;