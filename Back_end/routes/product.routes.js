// import express from "express";
// import { getAllProducts, addManyProducts, upload } from "../controllers/product.controller.js";

// const router = express.Router();

// router.post("/add-many", upload.single("image"), addManyProducts);
// router.get("/", getAllProducts);

// export default router;
import express from "express";
import { getProductById,getAllProducts, addManyProducts, upload } from "../controllers/product.controller.js";

const router = express.Router();

// ✅ Đổi từ upload.single sang upload.array để nhận nhiều ảnh
router.post("/add-many", upload.array("images", 50), addManyProducts);
router.get("/", getAllProducts);
router.get('/products/:id', getProductById);
export default router;