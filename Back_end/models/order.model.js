import mongoose from "mongoose";

// Schema cho item trong đơn hàng
const orderItemSchema = new mongoose.Schema({
  productId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "Product",
    required: true
  },
  productName: { type: String, required: true },
  productImage: { type: String, required: true },
  basePrice: { type: Number, required: true },
  selectedOption: {
    name: { type: String, default: "" },
    extraPrice: { type: Number, default: 0 }
  },
  quantity: { type: Number, required: true, min: 1 },
  unitPrice: { type: Number, required: true },
  totalPrice: { type: Number, required: true }
}, { _id: false });

// Schema cho đơn hàng
const orderSchema = new mongoose.Schema({
  // Thông tin người đặt
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "User",
    required: true
  },
  orderNumber: {
    type: String,
    unique: true,
    sparse: true // Cho phép undefined khi tạo mới
  },

  // Thông tin khách hàng
  customerName: { 
    type: String, 
    required: true,
    trim: true
  },
  customerPhone: { 
    type: String, 
    required: true,
    trim: true
  },
  deliveryAddress: { 
    type: String, 
    required: true,
    trim: true
  },
  note: { 
    type: String, 
    default: "",
    trim: true
  },

  // Thông tin đơn hàng
  items: [orderItemSchema],
  totalAmount: { 
    type: Number, 
    required: true,
    min: 0
  },
  
  // // Phương thức thanh toán
  // paymentMethod: {
  //   type: String,
  //   enum: ['cash', 'momo', 'banking'],
  //   default: 'cash'
  // },

  // Trạng thái đơn hàng
  status: {
    type: String,
    enum: ['hired', 'ready', 'cancelled'],
    default: 'ready'
  },

  // // Trạng thái thanh toán
  // paymentStatus: {
  //   type: String,
  //   enum: ['unpaid', 'paid', 'refunded'],
  //   default: 'unpaid'
  // },

  // Thời gian
  orderDate: {
    type: Date,
    default: Date.now
  },
  confirmedAt: Date,
  deliveredAt: Date,
  cancelledAt: Date,

  // Lý do hủy (nếu có)
  cancellationReason: String

}, { 
  timestamps: true 
});

// Middleware tạo order number tự động
orderSchema.pre('save', async function(next) {
  if (this.isNew && !this.orderNumber) {
    const date = new Date();
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    
    // Đếm số đơn hàng trong ngày
    const count = await mongoose.model('Order').countDocuments({
      orderDate: {
        $gte: new Date(date.setHours(0, 0, 0, 0)),
        $lt: new Date(date.setHours(23, 59, 59, 999))
      }
    });
    
    // Format: ORD-YYYYMMDD-XXXX
    this.orderNumber = `ORD-${year}${month}${day}-${String(count + 1).padStart(4, '0')}`;
  }
  next();
});

// Index để tìm kiếm nhanh
orderSchema.index({ userId: 1, orderDate: -1 });
orderSchema.index({ orderNumber: 1 });
orderSchema.index({ status: 1 });

const Order = mongoose.model("Order", orderSchema);

export default Order;