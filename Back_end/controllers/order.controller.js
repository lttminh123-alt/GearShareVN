import Order from "../models/order.model.js";
import Cart from "../models/cart.model.js";

// ✅ Tạo đơn hàng mới
export const createOrder = async (req, res) => {
  try {
    const userId = req.user.id;
    const { 
      customerName, 
      customerPhone, 
      deliveryAddress, 
      note, 
      paymentMethod 
    } = req.body;

    // Validate input
    if (!customerName || !customerPhone || !deliveryAddress) {
      return res.status(400).json({
        message: "Thiếu thông tin bắt buộc (tên, số điện thoại, địa chỉ)",
      });
    }

    // Lấy Đơn hàng của user
    const cart = await Cart.findOne({ userId });
    
    if (!cart || cart.items.length === 0) {
      return res.status(400).json({
        message: "Đơn hàng trống, không thể tạo đơn hàng",
      });
    }

    // Tạo đơn hàng mới
    const order = new Order({
      userId,
      customerName: customerName.trim(),
      customerPhone: customerPhone.trim(),
      deliveryAddress: deliveryAddress.trim(),
      note: note ? note.trim() : "",
      paymentMethod: paymentMethod || 'cash',
      items: cart.items.map(item => ({
        productId: item.productId,
        productName: item.productName,
        productImage: item.productImage,
        basePrice: item.basePrice,
        selectedOption: {
          name: item.selectedOption?.name || "",
          extraPrice: item.selectedOption?.extraPrice || 0
        },
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        totalPrice: item.totalPrice
      })),
      totalAmount: cart.totalAmount,
      status: 'pending',
      paymentStatus: paymentMethod === 'cash' ? 'unpaid' : 'paid'
    });

    // Lưu đơn hàng
    await order.save();

    // Xóa Đơn hàng sau khi đặt hàng thành công
    cart.items = [];
    cart.totalAmount = 0;
    cart.itemCount = 0;
    await cart.save();

    console.log(`✅ Đơn hàng ${order.orderNumber} đã được tạo`);

    res.status(201).json({
      message: "Đặt hàng thành công",
      order: {
        _id: order._id,
        orderNumber: order.orderNumber,
        customerName: order.customerName,
        customerPhone: order.customerPhone,
        deliveryAddress: order.deliveryAddress,
        totalAmount: order.totalAmount,
        paymentMethod: order.paymentMethod,
        status: order.status,
        orderDate: order.orderDate
      }
    });

  } catch (err) {
    console.error("❌ Lỗi khi tạo đơn hàng:", err);
    res.status(500).json({
      message: "Lỗi khi tạo đơn hàng",
      error: err.message,
    });
  }
};

// ✅ Lấy danh sách đơn hàng của user
export const getMyOrders = async (req, res) => {
  try {
    const userId = req.user.id;
    const { status, page = 1, limit = 10 } = req.query;

    const query = { userId };
    if (status) {
      query.status = status;
    }

    const skip = (page - 1) * limit;

    const orders = await Order.find(query)
      .sort({ orderDate: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .select('-__v');

    const total = await Order.countDocuments(query);

    res.status(200).json({
      orders,
      pagination: {
        total,
        page: parseInt(page),
        limit: parseInt(limit),
        totalPages: Math.ceil(total / limit)
      }
    });

  } catch (err) {
    console.error("❌ Lỗi khi lấy đơn hàng:", err);
    res.status(500).json({
      message: "Lỗi khi lấy danh sách đơn hàng",
      error: err.message,
    });
  }
};

// ✅ Lấy chi tiết đơn hàng
export const getOrderById = async (req, res) => {
  try {
    const userId = req.user.id;
    const { orderId } = req.params;

    const order = await Order.findOne({ 
      _id: orderId, 
      userId 
    }).populate('items.productId', 'name image price');

    if (!order) {
      return res.status(404).json({
        message: "Không tìm thấy đơn hàng",
      });
    }

    res.status(200).json(order);

  } catch (err) {
    console.error("❌ Lỗi khi lấy chi tiết đơn hàng:", err);
    res.status(500).json({
      message: "Lỗi khi lấy chi tiết đơn hàng",
      error: err.message,
    });
  }
};

// ✅ Hủy đơn hàng (chỉ khi status = pending)
export const cancelOrder = async (req, res) => {
  try {
    const userId = req.user.id;
    const { orderId } = req.params;
    const { reason } = req.body;

    const order = await Order.findOne({ 
      _id: orderId, 
      userId 
    });

    if (!order) {
      return res.status(404).json({
        message: "Không tìm thấy đơn hàng",
      });
    }

    if (order.status !== 'pending') {
      return res.status(400).json({
        message: "Không thể hủy đơn hàng đã được xác nhận",
      });
    }

    order.status = 'cancelled';
    order.cancelledAt = new Date();
    order.cancellationReason = reason || "Khách hàng hủy đơn";
    
    await order.save();

    res.status(200).json({
      message: "Đã hủy đơn hàng thành công",
      order
    });

  } catch (err) {
    console.error("❌ Lỗi khi hủy đơn hàng:", err);
    res.status(500).json({
      message: "Lỗi khi hủy đơn hàng",
      error: err.message,
    });
  }
};

// ✅ [ADMIN] Lấy tất cả đơn hàng
export const getAllOrders = async (req, res) => {
  try {
    const { status, page = 1, limit = 20 } = req.query;

    const query = {};
    if (status) {
      query.status = status;
    }

    const skip = (page - 1) * limit;

    const orders = await Order.find(query)
      .sort({ orderDate: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .populate('userId', 'name email phone')
      .select('-__v');

    const total = await Order.countDocuments(query);

    res.status(200).json({
      orders,
      pagination: {
        total,
        page: parseInt(page),
        limit: parseInt(limit),
        totalPages: Math.ceil(total / limit)
      }
    });

  } catch (err) {
    console.error("❌ Lỗi khi lấy đơn hàng:", err);
    res.status(500).json({
      message: "Lỗi khi lấy danh sách đơn hàng",
      error: err.message,
    });
  }
};

// ✅ [ADMIN] Cập nhật trạng thái đơn hàng
export const updateOrderStatus = async (req, res) => {
  try {
    const { orderId } = req.params;
    const { status } = req.body;

    const validStatuses = ['ready', 'hired', 'cancelled'];
    
    if (!validStatuses.includes(status)) {
      return res.status(400).json({
        message: "Trạng thái không hợp lệ",
      });
    }

    const order = await Order.findById(orderId);

    if (!order) {
      return res.status(404).json({
        message: "Không tìm thấy đơn hàng",
      });
    }

    // Cập nhật timestamp tương ứng
    // if (status === 'confirmed' && !order.confirmedAt) {
    //   order.confirmedAt = new Date();
    //}
    if (status === 'hired' && !order.deliveredAt) {
      order.deliveredAt = new Date();
      order.paymentStatus = 'paid'; // Tự động đánh dấu đã thanh toán khi giao hàng
    }
    if (status === 'cancelled' && !order.cancelledAt) {
      order.cancelledAt = new Date();
    }

    order.status = status;
    await order.save();

    res.status(200).json({
      message: "Đã cập nhật trạng thái đơn hàng",
      order
    });

  } catch (err) {
    console.error("❌ Lỗi khi cập nhật đơn hàng:", err);
    res.status(500).json({
      message: "Lỗi khi cập nhật đơn hàng",
      error: err.message,
    });
  }
};

// ✅ [ADMIN] Xóa đơn hàng
export const deleteOrder = async (req, res) => {
  try {
    const { orderId } = req.params;

    const order = await Order.findByIdAndDelete(orderId);

    if (!order) {
      return res.status(404).json({
        message: "Không tìm thấy đơn hàng",
      });
    }

    res.status(200).json({
      message: "Đã xóa đơn hàng thành công",
    });

  } catch (err) {
    console.error("❌ Lỗi khi xóa đơn hàng:", err);
    res.status(500).json({
      message: "Lỗi khi xóa đơn hàng",
      error: err.message,
    });
  }
};