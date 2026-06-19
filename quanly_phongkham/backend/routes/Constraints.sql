SET search_path TO quanly_phongkham, public;

-- CHECK Constraints
ALTER TABLE "BenhNhan" ADD CONSTRAINT "chk_benhnhan_gioitinh" CHECK ("GioiTinh" IN ('Nam', 'Nữ', 'Khác'));
ALTER TABLE "BenhNhan" ADD CONSTRAINT "chk_benhnhan_sdt" CHECK ("SDT" ~ '^0[0-9]{8,10}$');

ALTER TABLE "BacSi" ADD CONSTRAINT "chk_bacsi_sdt" CHECK ("SDT" ~ '^0[0-9]{8,10}$');

ALTER TABLE "LichHen" ADD CONSTRAINT "chk_lichhen_trangthai" CHECK ("TrangThai" IN ('Chờ khám', 'Đang khám', 'Đã khám', 'Đã hủy', 'Hoàn thành'));
ALTER TABLE "LichHen" ADD CONSTRAINT "chk_lichhen_thoigian" CHECK ("ThoiGianKetThuc" > "ThoiGianBatDau");

ALTER TABLE "CaLamViec" ADD CONSTRAINT "chk_calam_batdau_kethuc" CHECK ("BatDau" < "KetThuc");

ALTER TABLE "ChuKyTaiKham" ADD CONSTRAINT "chk_chuky_ngay" CHECK ("ChuKyNgay" > 0);
ALTER TABLE "ChuKyTaiKham" ADD CONSTRAINT "chk_chuky_trangthai" CHECK ("TrangThai" IN ('Đang hoạt động', 'Tạm dừng', 'Kết thúc'));

ALTER TABLE "Thuoc" ADD CONSTRAINT "chk_thuoc_dongia" CHECK ("DonGia" > 0);
ALTER TABLE "Thuoc" ADD CONSTRAINT "chk_thuoc_tonkho" CHECK ("SoLuongTon" >= 0);

ALTER TABLE "DonThuoc" ADD CONSTRAINT "chk_donthuoc_soluong" CHECK ("SoLuong" > 0);
ALTER TABLE "DonThuoc" ADD CONSTRAINT "chk_donthuoc_trangthai" CHECK ("TrangThai" IN ('Chờ phát thuốc', 'Đã phát thuốc', 'Chờ xử lý'));

ALTER TABLE "HoaDon" ADD CONSTRAINT "chk_hoadon_tongtien" CHECK ("TongTien" >= 0);
ALTER TABLE "HoaDon" ADD CONSTRAINT "chk_hoadon_tienkham" CHECK ("TienKham" >= 0);
ALTER TABLE "HoaDon" ADD CONSTRAINT "chk_hoadon_tienthuoc" CHECK ("TienThuoc" >= 0);
ALTER TABLE "HoaDon" ADD CONSTRAINT "chk_hoadon_phuongthuc" CHECK ("PhuongThuc" IN ('Tiền mặt', 'Chuyển khoản QR', 'Thẻ POS'));
ALTER TABLE "HoaDon" ADD CONSTRAINT "chk_hoadon_trangthai" CHECK ("TrangThai" IN ('Chưa thanh toán', 'Đã thanh toán', 'Đã hủy'));

ALTER TABLE "ChiTietDoanhThu" ADD CONSTRAINT "chk_doanhthu_giatri" CHECK ("DoanhThu" >= 0);

ALTER TABLE "NhacNho" ADD CONSTRAINT "chk_nhacnho_soluong" CHECK ("SoLuong" >= 0);
ALTER TABLE "LoiNhac" ADD CONSTRAINT "chk_loinhac_trangthai" CHECK ("TrangThai" IN ('Chưa gửi', 'Đã gửi', 'Lỗi kết nối'));

-- DEFAULT values
ALTER TABLE "LichHen" ALTER COLUMN "TrangThai" SET DEFAULT 'Chờ khám';
ALTER TABLE "ChuKyTaiKham" ALTER COLUMN "ChuKyNgay" SET DEFAULT 30;
ALTER TABLE "ChuKyTaiKham" ALTER COLUMN "BatDau" SET DEFAULT CURRENT_DATE;
ALTER TABLE "ChuKyTaiKham" ALTER COLUMN "TrangThai" SET DEFAULT 'Đang hoạt động';
ALTER TABLE "BenhAn" ALTER COLUMN "ThoiGianVao" SET DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE "BenhAn" ALTER COLUMN "NgayTao" SET DEFAULT CURRENT_DATE;
ALTER TABLE "Thuoc" ALTER COLUMN "DonVi" SET DEFAULT 'Viên';
ALTER TABLE "Thuoc" ALTER COLUMN "TenKho" SET DEFAULT 'Kho chính';
ALTER TABLE "HoaDon" ALTER COLUMN "NgayXuat" SET DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE "HoaDon" ALTER COLUMN "PhuongThuc" SET DEFAULT 'Tiền mặt';
ALTER TABLE "HoaDon" ALTER COLUMN "TrangThai" SET DEFAULT 'Chưa thanh toán';
ALTER TABLE "HoaDon" ALTER COLUMN "TongTien" SET DEFAULT 0;
ALTER TABLE "HoaDon" ALTER COLUMN "TienKham" SET DEFAULT 0;
ALTER TABLE "HoaDon" ALTER COLUMN "TienThuoc" SET DEFAULT 0;
ALTER TABLE "ChiTietDoanhThu" ALTER COLUMN "NgayGhiNhan" SET DEFAULT CURRENT_DATE;
ALTER TABLE "NhacNho" ALTER COLUMN "SoLuong" SET DEFAULT 0;
ALTER TABLE "LoiNhac" ALTER COLUMN "TrangThai" SET DEFAULT 'Chưa gửi';
ALTER TABLE "DonThuoc" ALTER COLUMN "TrangThai" SET DEFAULT 'Chờ xử lý';