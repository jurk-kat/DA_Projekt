----------------------------------------------------------------------------------------------
-- corrections of passenger counts & nationalities in the table 'harbour'
----------------------------------------------------------------------------------------------

UPDATE harbour SET passengers = 2194 WHERE boat = 'AIDAmar';
UPDATE harbour SET passengers = 1338 WHERE boat = 'Bolette';
UPDATE harbour SET passengers = 1353 WHERE boat = 'Borealis';
UPDATE harbour SET passengers = 200 WHERE boat = 'Gann';
UPDATE harbour SET passengers = 192 WHERE boat = 'SH Diana';
UPDATE nationalities SET nationality = N'German' WHERE nationality = N'German wealthy';
UPDATE nationalities SET nationality = N'UK' WHERE nationality = N'UK French';

----------------------------------------------------------------------------------------------
-- kolik procent z celku jednotlivych produktu zkoupi ktera narodnost?
-- zajima nas, kolik za co ktera narodnost utrati, kolik kusu ceho koupi a kolik je to procent z celkoveho revenue a celkoveho poctu za dany artikl
----------------------------------------------------------------------------------------------
;WITH kombi_tabulka AS
(
    SELECT
        h.DateTime,
        s.product,
        d.EN,
        s.units,
        s.total_price,
        h.boat,
        h.passengers,
        h.agent,
        n.nationality
    FROM 
        sales s
        JOIN harbour h ON s.DateTime = h.DateTime
        JOIN nationalities n ON h.boat = n.boat
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
    ROUND(SUM(k.total_price), 0) AS total_revenue,
    SUM(k.units) AS total_units_sold,
    ROUND((SUM(k.total_price) * 100.0 / pt.total_revenue_product), 1) AS revenue_percentage,
    ROUND((SUM(k.units) * 100.0 / pt.total_units_product), 1) AS units_percentage
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
    k.nationality;

----------------------------------------------------------------------------------------------
-- Co ktera narodnost procentuelne nakupuje?
-- divame se z pohledu narodnosti a co kupuji, ne z pohledu kolik procent ceho ktera narodnost koupi. Lepe zohlednuje fakt, ze narosnosti nemaji v obchode stejne zastoupeni.
----------------------------------------------------------------------------------------------
;WITH kombi_tabulka AS
(
    SELECT
        h.DateTime,
        s.product,
        d.EN,
        s.units,
        s.total_price,
        h.boat,
        h.passengers,
        h.agent,
        n.nationality
    FROM 
        sales s
        JOIN harbour h ON s.DateTime = h.DateTime
        JOIN nationalities n ON h.boat = n.boat
        JOIN dictionary d ON s.product = d.product
),
total_revenue AS
(
    SELECT
        nationality,
        SUM(total_price) AS total_revenue,
        SUM(units) AS total_units
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
        SUM(total_price) AS product_revenue,
        SUM(units) AS product_units
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
    percentage_of_total_revenue DESC;
