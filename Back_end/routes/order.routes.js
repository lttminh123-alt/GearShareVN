import express from "express";
import { 
  createOrder, 
  getMyOrders, 
  getOrderById, 
  cancelOrder,
  getAllOrders,
  updateOrderStatus,
  deleteOrder
} from "../controllers/order.controller.js";

import authMiddleware from "../middlewares/auth.js";

const router = express.Router();

// ✅ Routes cho User (cần xác thực)
router.post("/create", authMiddleware, createOrder);           // Tạo đơn hàng mới
router.get("/my-orders", authMiddleware, getMyOrders);         // Lấy đơn hàng của mình
router.get("/:orderId", authMiddleware, getOrderById);         // Chi tiết đơn hàng
router.put("/:orderId/cancel", authMiddleware, cancelOrder);   // Hủy đơn hàng

// ✅ Routes cho Admin (cần xác thực + role admin)
// Nếu có middleware kiểm tra admin, thêm vào đây
// Ví dụ: router.get("/admin/all", authMiddleware, isAdmin, getAllOrders);
router.get("/admin/all", authMiddleware, getAllOrders);                    // Lấy tất cả đơn hàng
router.put("/admin/:orderId/status", authMiddleware, updateOrderStatus);   // Cập nhật trạng thái
router.delete("/admin/:orderId", authMiddleware, deleteOrder);             // Xóa đơn hàng

export default router;