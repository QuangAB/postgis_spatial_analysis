-- Khởi tạo Spatial View phục vụ GIS

CREATE OR REPLACE VIEW hanh_lang_giao_thong AS
SELECT
	row_number() OVER () AS id,
	xp.name_3 AS ten_xa_phuong,
	COUNT(gtc.id) AS so_tuyen_duong_tac_dong,
	ROUND(
		SUM(
			ST_Area(
				ST_Transform(
					ST_Intersection(
						ST_Buffer(gtc.geom::geography, 50)::geometry, xp.geom
					),
					32648
				)
			)
		)::numeric, 2
	) AS tong_dien_tich_anh_huong_m2,
	xp.geom
FROM giao_thong_chinh gtc
INNER JOIN xa_phuong xp
ON ST_Intersects(ST_Buffer(gtc.geom::geography, 50)::geometry, xp.geom)
GROUP BY xp.name_3, xp.geom;
