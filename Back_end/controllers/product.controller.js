import multer from "multer";
import Product from "../models/product.model.js";
import path from "path";
import fs from "fs";

// ✅ Tạo thư mục uploads nếu chưa tồn tại
const uploadsDir = "uploads";
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}

// ✅ Cấu hình multer storage
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadsDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + "-" + Math.round(Math.random() * 1e9);
    const ext = path.extname(file.originalname);
    cb(null, uniqueSuffix + ext);
  },
});

// ✅ Cấu hình multer
export const upload = multer({
  storage: storage,
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB
  },
  fileFilter: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    const allowedExts = ['.jpeg', '.jpg', '.png', '.gif', '.webp'];
    
    if (allowedExts.includes(ext)) {
      cb(null, true);
    } else {
      console.log(`❌ File bị từ chối: ${file.originalname}, mimetype: ${file.mimetype}`);
      cb(new Error(`Chỉ chấp nhận file ảnh. File nhận được: ${ext}`));
    }
  },
});

// ✅ Thêm nhiều sản phẩm (với ảnh và options từ Flutter)
export const addManyProducts = async (req, res) => {
  try {
    const files = req.files || [];
    console.log(`📦 Nhận được ${files.length} file ảnh`);

    if (!req.body.products) {
      return res.status(400).json({ 
        message: "Thiếu dữ liệu products" 
      });
    }

    const productsData = JSON.parse(req.body.products);
    console.log(`📝 Nhận được ${productsData.length} sản phẩm`);

    // Map ảnh với từng sản phẩm và xử lý options
    const products = productsData.map((p, index) => {
      const { _id, localId, ...data } = p;

      const imagePath = files[index] 
        ? `/uploads/${files[index].filename}` 
        : (data.image || "");

      // ✅ Xử lý options - đảm bảo có cấu trúc đúng
      const options = data.options ? data.options.map(opt => ({
        name: opt.name || "",
        extraPrice: opt.extraPrice || 0
      })) : [];

      console.log(`🖼️ Sản phẩm "${data.name}" -> ${imagePath}`);
      console.log(`⚙️ Options: ${JSON.stringify(options)}`);

      return {
        ...data,
        image: imagePath,
        options: options, // ✅ Thêm options vào product
      };
    });

    // Lưu vào database
    const result = await Product.insertMany(products);
    
    console.log(`✅ Đã lưu ${result.length} sản phẩm vào database`);
    
    res.status(201).json({
      message: "Thêm sản phẩm thành công",
      count: result.length,
      products: result,
    });

  } catch (err) {
    console.error("❌ Lỗi khi thêm sản phẩm:", err);
    
    // Xóa các file đã upload nếu có lỗi
    if (req.files) {
      req.files.forEach(file => {
        fs.unlink(file.path, (unlinkErr) => {
          if (unlinkErr) console.error("Lỗi xóa file:", unlinkErr);
        });
      });
    }

    res.status(500).json({ 
      message: "Lỗi khi thêm sản phẩm", 
      error: err.message 
    });
  }
};

// ✅ Lấy tất cả sản phẩm
export const getAllProducts = async (req, res) => {
  try {
    const products = await Product.find();
    res.status(200).json(products);
  } catch (err) {
    console.error("❌ Lỗi khi lấy danh sách sản phẩm:", err);
    res.status(500).json({ 
      message: "Lỗi khi lấy danh sách sản phẩm", 
      error: err.message 
    });
  }
};

// ✅ Xóa tất cả sản phẩm
export const deleteAllProducts = async (req, res) => {
  try {
    await Product.deleteMany({});
    console.log("🗑️ Đã xóa tất cả sản phẩm");
    res.status(200).json({ message: "Đã xóa tất cả sản phẩm" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ✅ Xóa sản phẩm (kèm xóa ảnh)
export const deleteProduct = async (req, res) => {
  try {
    const { id } = req.params;
    const product = await Product.findById(id);
    
    if (!product) {
      return res.status(404).json({ message: "Không tìm thấy sản phẩm" });
    }

    // Xóa file ảnh nếu có
    if (product.image && product.image.startsWith('/uploads/')) {
      const imagePath = product.image.replace('/uploads/', 'uploads/');
      if (fs.existsSync(imagePath)) {
        fs.unlinkSync(imagePath);
        console.log(`🗑️ Đã xóa ảnh: ${imagePath}`);
      }
    }

    await Product.findByIdAndDelete(id);
    
    res.status(200).json({ 
      message: "Xóa sản phẩm thành công",
      deletedProduct: product 
    });

  } catch (err) {
    console.error("❌ Lỗi khi xóa sản phẩm:", err);
    res.status(500).json({ 
      message: "Lỗi khi xóa sản phẩm", 
      error: err.message 
    });
  }
};

// ✅ Lấy chi tiết 1 sản phẩm theo ID
export const getProductById = async (req, res) => {
  try {
    const { id } = req.params;
    const product = await Product.findById(id);
    
    if (!product) {
      return res.status(404).json({ message: "Không tìm thấy sản phẩm" });
    }
    
    res.status(200).json(product);
  } catch (err) {
    console.error("❌ Lỗi khi lấy sản phẩm:", err);
    res.status(500).json({ 
      message: "Lỗi khi lấy sản phẩm", 
      error: err.message 
    });
  }
};