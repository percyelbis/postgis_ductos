---seleccionará todos los polígonos que no se superponen con otros polígonos y no son huecos
CREATE VIEW cons AS
SELECT p.*
FROM public.tg_construcciones AS p
WHERE NOT EXISTS (
    SELECT 1
    FROM public.tg_construcciones AS p2
    WHERE p.gid != p2.gid AND ST_Intersects(p.geom, p2.geom) AND ST_Contains(p2.geom, p.geom)
);



---seleccionará el polígono más pequeño que se superpone con otros polígonos.
CREATE VIEW hueco AS
SELECT p.*
FROM public.tg_construcciones AS p
WHERE ST_Area(p.geom) IN (
    SELECT ST_Area(ST_Intersection(p.geom, p2.geom))
    FROM public.tg_construcciones AS p2
    WHERE p.gid != p2.gid AND ST_Intersects(p.geom, p2.geom)
    AND ST_Area(p.geom) < (
        SELECT MAX(ST_Area(geom))
        FROM public.tg_construcciones
    )
);



---- crear indices espaciales
CREATE MATERIALIZED VIEW cons3 AS
SELECT *
FROM cons;

CREATE MATERIALIZED VIEW hueco3 AS
SELECT *
FROM hueco;


CREATE INDEX cons_geom_idx ON cons3 USING GIST (geom);
CREATE INDEX hueco_geom_idx ON hueco3 USING GIST (geom);

------ CREAR DONAS
CREATE VIEW donitas AS
SELECT subq.gid, ST_Union(ST_Difference(subq.geom, hueco.geom)) AS geom
FROM (
    SELECT c.gid, c.geom, h.geom AS hueco_geom
    FROM cons3 c
    INNER JOIN hueco3 h ON ST_Intersects(c.geom, h.geom)
) AS subq
CROSS JOIN LATERAL (
    SELECT ST_Union(h.hueco_geom) AS geom
    FROM (
        SELECT h.geom AS hueco_geom
        FROM hueco3 h
        WHERE ST_Intersects(subq.geom, h.geom)
    ) AS h
) AS hueco
WHERE NOT ST_Touches(subq.geom, hueco.geom)
GROUP BY subq.gid

UNION ALL

SELECT cons3.gid, cons3.geom
FROM cons3
WHERE NOT EXISTS (
    SELECT 1
    FROM hueco3
    WHERE ST_Intersects(cons3.geom, hueco3.geom)
);
