-- 1. TẠO SCHEMA VÀ ĐẶT ĐƯỜNG DẪN ƯU TIÊN
SET search_path TO quanly_phongkham, public;

-- XÓA CÁC BẢNG CŨ (NẾU CÓ) ĐỂ RE-SET TOÀN BỘ HỆ THỐNG
DROP TABLE IF EXISTS "LoiNhac" CASCADE;
DROP TABLE IF EXISTS "LichSuNhacNho" CASCADE;
DROP TABLE IF EXISTS "MauLoiNhac" CASCADE;
DROP TABLE IF EXISTS "ThietLapNhacNho" CASCADE;
DROP TABLE IF EXISTS "NhacNho" CASCADE;
DROP TABLE IF EXISTS "ChiTietDoanhThu" CASCADE;
DROP TABLE IF EXISTS "HoaDon" CASCADE;
DROP TABLE IF EXISTS "DonThuoc" CASCADE;
DROP TABLE IF EXISTS "Thuoc" CASCADE;
DROP TABLE IF EXISTS "BenhAn" CASCADE;
DROP TABLE IF EXISTS "ChuKyTaiKham" CASCADE;
DROP TABLE IF EXISTS "LichHen" CASCADE;
DROP TABLE IF EXISTS "CaLamViec" CASCADE;
DROP TABLE IF EXISTS "BacSi" CASCADE;
DROP TABLE IF EXISTS "PhongKham" CASCADE;
DROP TABLE IF EXISTS "BenhNhan" CASCADE;

-- =========================================================================
-- 2. KHỞI TẠO CÁC BẢNG DỮ LIỆU CHÍNH THỨC
-- =========================================================================

-- Bảng 1: Bệnh Nhân
CREATE TABLE "BenhNhan" (
    "MaBN" VARCHAR(20) PRIMARY KEY,
    "HoTen" VARCHAR(100) NOT NULL,
    "NgaySinh" DATE,
    "GioiTinh" VARCHAR(10) NOT NULL,
    "SDT" VARCHAR(15)
);

-- Bảng 2: Phòng Khám
CREATE TABLE "PhongKham" (
    "MaPK" INT PRIMARY KEY,
    "TenPhong" VARCHAR(100) NOT NULL,
    "ChuyenKhoa" VARCHAR(100) NOT NULL DEFAULT 'Đa khoa'
);

-- Bảng 3: Bác Sĩ
CREATE TABLE "BacSi" (
    "MaBS" VARCHAR(20) PRIMARY KEY,
    "HoTen" VARCHAR(100) NOT NULL,
    "ChuyenKhoa" VARCHAR(100) NOT NULL,
    "SDT" VARCHAR(15),
    "MaPK" INT REFERENCES "PhongKham"("MaPK") ON DELETE SET NULL
);

-- Bảng 4: Ca Làm Việc
CREATE TABLE "CaLamViec" (
    "MaCa" SERIAL PRIMARY KEY,
    "MaBS" VARCHAR(20) NOT NULL REFERENCES "BacSi"("MaBS") ON DELETE CASCADE,
    "NgayLam" DATE NOT NULL,
    "BatDau" TIME NOT NULL,
    "KetThuc" TIME NOT NULL,
    CHECK ("BatDau" < "KetThuc")
);

-- Bảng 5: Lịch Hẹn
CREATE TABLE "LichHen" (
    "MaLH" SERIAL PRIMARY KEY,
    "MaBN" VARCHAR(20) NOT NULL REFERENCES "BenhNhan"("MaBN") ON DELETE CASCADE,
    "MaBS" VARCHAR(20) NOT NULL REFERENCES "BacSi"("MaBS") ON DELETE CASCADE,
    "ThoiGianBatDau" TIMESTAMP NOT NULL,
    "ThoiGianKetThuc" TIMESTAMP NOT NULL,
    "TrangThai" VARCHAR(50) NOT NULL DEFAULT 'Chờ khám'
);

-- Bảng 6: Chu Kỳ Tái Khám
CREATE TABLE "ChuKyTaiKham" (
    "MaChuKy" SERIAL PRIMARY KEY,
    "MaBN" VARCHAR(20) NOT NULL REFERENCES "BenhNhan"("MaBN") ON DELETE CASCADE,
    "MaBS" VARCHAR(20) REFERENCES "BacSi"("MaBS") ON DELETE SET NULL,
    "ChuKyNgay" INT NOT NULL DEFAULT 30,
    "BatDau" DATE NOT NULL DEFAULT CURRENT_DATE,
    "KetThuc" DATE,
    "TrangThai" VARCHAR(50) NOT NULL DEFAULT 'Đang hoạt động'
);

-- Bảng 7: Bệnh Án
CREATE TABLE "BenhAn" (
    "MaBA" SERIAL PRIMARY KEY,
    "MaLH" INT REFERENCES "LichHen"("MaLH") ON DELETE SET NULL,
    "ThoiGianVao" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "ChanDoan" TEXT NOT NULL,
    "TrieuChung" TEXT,
    "GhiChu" TEXT,
    "NgayTao" DATE NOT NULL DEFAULT CURRENT_DATE
);

-- Bảng 8: Thuốc (có cột tồn kho)
CREATE TABLE "Thuoc" (
    "MaThuoc" VARCHAR(30) PRIMARY KEY,
    "TenThuoc" VARCHAR(100) NOT NULL,
    "DonVi" VARCHAR(20) NOT NULL DEFAULT 'Viên',
    "TenKho" VARCHAR(50) DEFAULT 'Kho chính',
    "NhaSX" VARCHAR(100),
    "DonGia" DECIMAL(10, 2) NOT NULL,
    "SoLuongTon" INT NOT NULL DEFAULT 0
);

-- Bảng 9: Đơn Thuốc
CREATE TABLE "DonThuoc" (
    "MaDon" SERIAL PRIMARY KEY,
    "MaBA" INT NOT NULL REFERENCES "BenhAn"("MaBA") ON DELETE CASCADE,
    "MaThuoc" VARCHAR(30) NOT NULL REFERENCES "Thuoc"("MaThuoc") ON DELETE RESTRICT,
    "SoLuong" INT NOT NULL,
    "LieuDung" VARCHAR(150),
    "HuongDan" TEXT,
    "TrangThai" VARCHAR(50) NOT NULL DEFAULT 'Chờ xử lý'
);

ALTER TABLE "DonThuoc" ADD CONSTRAINT "uq_donthuoc_maba_mathuoc" UNIQUE ("MaBA", "MaThuoc");

-- Bảng 10: Hóa Đơn
CREATE TABLE "HoaDon" (
    "MaHD" SERIAL PRIMARY KEY,
    "MaBA" INT NOT NULL REFERENCES "BenhAn"("MaBA") ON DELETE CASCADE,
    "NgayXuat" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "PhuongThuc" VARCHAR(50) NOT NULL DEFAULT 'Tiền mặt',
    "TrangThai" VARCHAR(50) NOT NULL DEFAULT 'Chưa thanh toán',
    "TongTien" DECIMAL(12, 2) NOT NULL DEFAULT 0,
    "TienKham" DECIMAL(12, 2) NOT NULL DEFAULT 0,
    "TienThuoc" DECIMAL(12, 2) NOT NULL DEFAULT 0
);

-- Bảng 11: Chi Tiết Doanh Thu
CREATE TABLE "ChiTietDoanhThu" (
    "MaDT" SERIAL PRIMARY KEY,
    "MaHD" INT NOT NULL REFERENCES "HoaDon"("MaHD") ON DELETE CASCADE,
    "DoanhThu" DECIMAL(12, 2) NOT NULL,
    "NgayGhiNhan" DATE NOT NULL DEFAULT CURRENT_DATE
);

-- Bảng 12: Nhắc Nhở (cũ, giữ lại để tương thích)
CREATE TABLE "NhacNho" (
    "MaNN" SERIAL PRIMARY KEY,
    "MaBN" VARCHAR(20) NOT NULL REFERENCES "BenhNhan"("MaBN") ON DELETE CASCADE,
    "MaChuKy" INT NOT NULL REFERENCES "ChuKyTaiKham"("MaChuKy") ON DELETE CASCADE,
    "SoLuong" INT NOT NULL DEFAULT 0
);

-- Bảng 13: Lời Nhắc (cũ)
CREATE TABLE "LoiNhac" (
    "MaNN" INT NOT NULL REFERENCES "NhacNho"("MaNN") ON DELETE CASCADE,
    "ThoiGianGui" TIMESTAMP NOT NULL,
    "TrangThai" VARCHAR(50) NOT NULL DEFAULT 'Chưa gửi',
    PRIMARY KEY ("MaNN", "ThoiGianGui")
);