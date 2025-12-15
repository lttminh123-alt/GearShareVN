import mongoose from "mongoose";
      // ta sẽ tạo những mục như là user và email và số điện thoại và mật khẩu 
      // dùng type để định dạng nhập dữ liệu , require dùng để bắt buộc nhập để tránh lỗi khi bỏ trống ,
      // dùng trim để xoá nhugng khoảng trống từ vd tôi nhập là" trần mạnh tèo " thì sao khi dùng trim ta sẽ có "trần mạnh tèo"
const userSchema = new mongoose.Schema({
  username: { type: String, required: true, trim: true },
  email: { type: String, required: true, unique: true },
  phone_number: {
    type: String,
    required: true,
    unique: true,
  // chúng ta sẽ dùng thêm một hàm để khi nhập sẽ khắt khe hơn 
  //ta sẽ dùng match
    match: [/^(\+84|0)[0-9]{9,10}$/, "Số điện thoại không hợp lệ"],
  },
  password: { type: String, required: true, trim: true },
   // tiếp theo ta sẽ phân quyền có 3 quyền là admin , nhân viên và người dùng
  role: {
    type: String,
    enum: ["admin", "user"],
    default: "user",
  },

  //thêm mục yêu thích cho người dùng
    favorites: [
    {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Product",
    },
  ],
  // ta sẽ ghi lại thòi gian khi người dùng tạo tài khoản hoặc cập nhật 
}, { timestamps: true });
// cuối cùng ta sẽ đặt tên bảng là User và tạo biến để hứng nó từ userShema 
export default mongoose.model("User", userSchema);
