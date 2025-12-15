import mongoose from "mongoose";

// Schema cho item trong Đơn hàng
const cartItemSchema = new mongoose.Schema({
  productId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "Product",
    required: true
  },
  productName: { type: String, required: true },
  productImage: { type: String, required: true },
  basePrice: { type: Number, required: true }, // Giá gốc của sản phẩm
  selectedOption: {
    name: { type: String, default: "" },
    extraPrice: { type: Number, default: 0 }
  },
  quantity: { type: Number, required: true, min: 1 },
  unitPrice: { type: Number, required: true }, // basePrice + extraPrice
  totalPrice: { type: Number, required: true } // unitPrice * quantity
}, { _id: false });

// Schema cho Đơn hàng
const cartSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "User",
    required: true,
    unique: true // Mỗi user chỉ có 1 Đơn hàng
  },
  items: [cartItemSchema],
  totalAmount: { type: Number, default: 0 }, // Tổng tiền của toàn bộ Đơn hàng
  itemCount: { type: Number, default: 0 } // Tổng số lượng items
}, { 
  timestamps: true 
});

// Middleware tự động tính tổng tiền trước khi save
cartSchema.pre('save', function(next) {
  this.totalAmount = this.items.reduce((sum, item) => sum + item.totalPrice, 0);
  this.itemCount = this.items.reduce((sum, item) => sum + item.quantity, 0);
  next();
});

const Cart = mongoose.model("Cart", cartSchema);

export default Cart;