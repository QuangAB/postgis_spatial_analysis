# Phân tích Không gian và Quản trị CSDL với PostgreSQL & PostGIS

## 📌 Giới thiệu Dự án

Dự án này tập trung vào việc quản trị cơ sở dữ liệu không gian (Spatial Database Administration) và xây dựng các câu lệnh truy vấn **Spatial SQL** sử dụng **PostgreSQL** và extension **PostGIS**. 

Mục tiêu chính của dự án là tự động hóa các phép tính hình học không gian phức tạp (tạo vùng đệm 50m hành lang giao thông, giao cắt không gian, chuyển đổi hệ tọa độ phẳng và tổng hợp diện tích bị ảnh hưởng theo từng Xã/Phường) trực tiếp trên cơ sở dữ liệu, đồng thời chuyển đổi kết quả thành một **Spatial View** để trực quan hóa trên **QGIS**.

---

## 🗂️ Cấu trúc Thư mục và Cơ sở dữ liệu

```
postgis_spatial_analysis/
│
├── sql/
│   ├── 01_spatial_join_aggregation.sql        # Truy vấn phân tích vùng đệm & diện tích
│   └── 02_create_spatial_view.sql             # Khởi tạo Spatial View phục vụ GIS
│
├── data/
│   └── hcm_spatial_db.backup                  # Bản sao lưu CSDL PostgreSQL/PostGIS
│
└── README.md                                  # Tài liệu chi tiết dự án
```

---

## ⚙️ Thiết lập Cơ sở dữ liệu Không gian

1. **Khởi tạo Database & Kích hoạt PostGIS Extension trong pgAdmin4:**
   ```sql
   CREATE DATABASE hcm_spatial_db;
   \c hcm_spatial_db;
   CREATE EXTENSION postgis;
   ```

2. **Nạp dữ liệu không gian:**
   * Sử dụng công cụ **QGIS DB Manager** trong QGIS để import các tập tin dữ liệu vector chính vào PostgreSQL/PostGIS dưới hệ tọa độ địa lý WGS 84 (`EPSG:4326`):
     * Bảng `xa_phuong`: Ranh giới hành chính cấp Xã/Phường TP.HCM (từ file RanhGioi_Xa&Phuong_HCM.gpkg)
     * Bảng `giao_thong_chinh`: Mạng lưới đường giao thông chính TP.HCM (từ file GiaoThongChinh_HCM.gpkg).

---

## 💻 Đoạn mã truy vấn Spatial SQL

### 1. Phân tích Vùng đệm 50m, Giao cắt và Thống kê Diện tích theo Xã/Phường

```sql
-- Truy vấn phân tích vùng đệm và diện tích
SELECT
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
	) AS tong_dien_tich_anh_huong_m2
FROM giao_thong_chinh gtc
INNER JOIN xa_phuong xp
ON ST_Intersects(ST_Buffer(gtc.geom::geography, 50)::geometry, xp.geom)
GROUP BY xp.name_3
ORDER BY tong_dien_tich_anh_huong_m2 DESC;
```

### 2. Khởi tạo Spatial View trực quan hóa trên QGIS (`vw_hanh_lang_giao_thong_xa`)

```sql
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
```

## 📈 Kết quả thu được

Sau khi thực thi truy vấn Spatial SQL trong PostgreSQL/PostGIS, hệ thống đã phân tích thành công **169 xã/phường** chịu tác động bởi hành lang giao thông 50m.

### 1. Bảng Top 10 Xã/Phường có diện tích hành lang giao thông bị ảnh hưởng lớn nhất:

| STT | Tên Xã / Phường (`ten_xa_phuong`) | Số tuyến đường tác động (`so_tuyen_duong_tac_dong`) | Tổng diện tích ảnh hưởng ($m^2$) (`tong_dien_tich_anh_huong_m2`) |
| :---: | :--- | :---: | :---: |
| **1** | An Phú | 383 | **8,348,350.96** |
| **2** | Tân Phú | 505 | **7,495,647.61** |
| **3** | Phường 13 | 464 | **5,457,319.03** |
| **4** | Linh Trung | 406 | **5,356,029.48** |
| **5** | Phường 10 | 485 | **5,053,755.76** |
| **6** | Thạnh Mỹ Lợi | 278 | **5,005,835.84** |
| **7** | Phường 7 | 471 | **4,833,777.07** |
| **8** | Phú Hữu | 188 | **4,733,041.32** |
| **9** | Phường 1 | 504 | **4,699,817.03** |
| **10** | Long Hòa | 73 | **4,626,599.85** |

### 2. Chỉ số Thống kê Tổng quan Toàn vùng:

* **Tổng số xã/phường ghi nhận ảnh hưởng:** `169` đơn vị hành chính.
* **Tổng diện tích hành lang giao thông toàn TP:** `295,232,676.30` $m^2$ ($\approx 295.23$ $km^2$).
* **Thời gian thực hiện truy vấn (Query Execution Time):** `00:00:04.029` ($\approx 4$ giây cho toàn bộ các phép toán hình học lồng nhau trên CSDL).
