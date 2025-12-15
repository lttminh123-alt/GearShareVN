import mongoose from "mongoose";

// Schema cho options/topping
const optionSchema = new mongoose.Schema({
  name: { type: String, required: true },
  extraPrice: { type: Number, default: 0 }
}, { _id: false }); // _id: false để không tạo _id cho mỗi option

// Schema cho Product
const productSchema = new mongoose.Schema({
  name: { type: String, required: true },
  image: { type: String, required: true },
  price: { type: Number, required: true },
  rating: { type: Number, default: 0 },
  category: { type: String, required: true },
  description: { type: String, default: "" },
  options: [optionSchema], // ✅ Đổi từ "option" thành "options" (số nhiều)
}, { 
  timestamps: true // Tự động tạo createdAt và updatedAt
});

const Product = mongoose.model("Product", productSchema);

export default Product;