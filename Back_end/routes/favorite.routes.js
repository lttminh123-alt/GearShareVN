import express from "express";
import { toggleFavorite, getFavorites } from "../controllers/favorite.controller.js";
import authMiddleware from "../middlewares/auth.js"; // middleware decode token

const router = express.Router();

router.post("/toggle", authMiddleware, toggleFavorite);
router.get("/", authMiddleware, getFavorites);

export default router;
