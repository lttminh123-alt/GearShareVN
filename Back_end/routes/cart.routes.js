import express from "express";
import { 
  addToCart, 
  getCart, 
  updateCartItem, 
  removeFromCart, 
  clearCart 
} from "../controllers/cart.controller.js";

import authMiddleware from "../middlewares/auth.js"; // middleware decode token
const router = express.Router();

// ✅ Tất cả routes đều cần xác thực
router.post("/add", authMiddleware , addToCart);
router.get("/", authMiddleware , getCart);
router.put("/update", authMiddleware , updateCartItem);
router.delete("/remove", authMiddleware , removeFromCart);
router.delete("/clear", authMiddleware , clearCart);

export default router;