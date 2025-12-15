// import User from "../models/user.model.js";

// // ta sẽ tạo hàm đăng ký 

// export const register = async (req, res) =>{
//     try{
//         // tạo hàm ghi tắt lấy từ models user
//         const {username , email, phone_number, role} = req.body;

//         // tạo hàm kiểm tra email , không được cho trùng

//         const existing_email = await User.findOne({email})
//         if (existing_email){
//             return res.status(400).json({messsage: "Email đã được sử dụng"});
//         }
//         //tạo thêm hàm kiểm tra số điện thoại , không được cho trùng

//         const existing_phone_number = await User.findOne({phone_number})
//         if (existing_phone_number){
//             return res.status(400).json({messsage:" Số điện thoại đã tồn tại"})
//         }

//         // tạo một biến chứa mật khẩu và mã hoá nó 
//         const hashedPassWord = await bcrypt.hash("Password",10);

//         // sau khi nhập đầy đủ thông tin sẽ tạo dữ liệu user mói
//         const newUser =  new User(
//             {
//                 // chứa tên ,email và số điện thoại
//                 // và cho role mặc định là người mua (user)
//                 username,
//                 email,
//                 phone_number,
//                 role: role || "user",
//             }
//         );

//         // sau khi nhập đầy đủ và tạo dữ liệu hay nói cách khác là xử lý dữ diêuyj và nếu hợp lệ ta sẽ lưu chúng và thông báo bằng json

//         const Save_New_User = await newUser.save();

//         res.status(201).json({messsage: "Tài khoản đã đăng ký thành công",
//             user : {
//                 id: Save_New_User._id,
//                 username: Save_New_User.username,
//                 phone_number: Save_New_User.phone_number,
//                 email : Save_New_User.email,
//                 role : Save_New_User.role,
//             },

//         });
      

//     }
//     //sau khi try để xử lý nếu lỗi ta sẽ dùng catch để bắt
//       catch(error){
//             res.status(500).json({messsage:error.messsage})
//         }
// }

// // sau khi đăng ký xong ta sẽ đăng nhập

// export const loggin = async (req,res)=> {
//     // kiểm tra email và số điện thoại của người có nhập đúng không 
//     try{
//         // tạo hàm để lấy dữ liệu 
//         const{email, phone_number ,passWord} = req.body;

//         const User_email = await User.findOne(email)

//         if(!User_email)
//             return res.status(404).json({messsage:"Email không tồn tại"});
        
        
//         const User_phone_number =await User.findOne(phone_number,)

//         if (!User_phone_number)
//             return res.status(404).json({messsage:"Số điện thoại không tồn tại"});

        
//         // kiểm tra mật khẩu có nhập đúng không  
//         const isMatch = await bcrypt.compare(passWord, user.passWord);
//         if (!isMatch)
//             return res.status(400).json({ message: "Mật khẩu không chính xác" }); 
        
            
//         // sau khi đăng nhập xong ta sẽ token cho nó
//         const token = jwt.sign(
//             {id:user._id, role :user.role},
//             process.env.JWT_SECRET || "secret_key",
//             {exporesIn: "1h"}
//         );

//         res.json({
//             message: "Đăng nhập thành công",
//             token,
//             user: {
//                 id: user._id,
//                 username: user.username,
//                 email: user.email,
//                 role: user.role,
//             }
//         });
//       }
//       catch (error) {
//         res.status(500).json({ message: error.message });
//         }  
// };


import User from "../models/user.model.js";
import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";

export const registerUser = async (req, res) => {
  try {
    const { username, email, phone_number, password, role } = req.body;

    if (await User.findOne({ email }))
      return res.status(400).json({ message: "Email đã được sử dụng" });

    if (await User.findOne({ phone_number }))
      return res.status(400).json({ message: "Số điện thoại đã tồn tại" });

    const hashedPassword = await bcrypt.hash(password, 10);
    const newUser = new User({
      username,
      email,
      phone_number,
      password: hashedPassword,
      role: role || "user",
    });

    const saved = await newUser.save();
    res.status(201).json({
      message: "Tài khoản đăng ký thành công",
      user: {
        id: saved._id,
        username: saved.username,
        email: saved.email,
        role: saved.role,
      },
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// export const loginUser = async (req, res) => {
//   try {
//     const { email, password } = req.body;
//     const user = await User.findOne({ email });
//     if (!user)
//       return res.status(404).json({ message: "Email không tồn tại" });

//     const isMatch = await bcrypt.compare(password, user.password);
//     if (!isMatch)
//       return res.status(400).json({ message: "Mật khẩu không chính xác" });

//     const token = jwt.sign(
//       { id: user._id, role: user.role },
//       process.env.JWT_SECRET || "secret_key",
//       { expiresIn: "1h" }
//     );

//     res.json({
//       message: "Đăng nhập thành công",
//       token,
//       user: {
//         id: user._id,
//         username: user.username,
//         email: user.email,
//         role: user.role,
//       },
//     });
//   } catch (err) {
//     res.status(500).json({ message: err.message });
//   }
// };

export const loginUser = async (req, res) => {
  try {
    const { email, phone_number, password } = req.body;

    // Tìm người dùng bằng email hoặc số điện thoại
    const user = await User.findOne({
      $or: [
        { email: email },
        { phone_number: phone_number }
      ],
    });

    if (!user)
      return res.status(404).json({ message: "Email hoặc SĐT không tồn tại" });

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch)
      return res.status(400).json({ message: "Mật khẩu không chính xác" });

    const token = jwt.sign(
      { id: user._id, role: user.role },
      process.env.JWT_SECRET || "secret_key",
      { expiresIn: "1h" }
    );

    res.json({
      message: "Đăng nhập thành công",
      token,
      user: {
        id: user._id,
        username: user.username,
        email: user.email,
        phone_number: user.phone_number,
        role: user.role,
      },
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};


//ta sẽ tạo hàm xử lý , lấy dữ liệu và xuất ra dữ liệu

export const getAllUsers = async( _ , res)=> {
    try{
        const user = await User.find();
        res.json(user);
    }
    catch(error){
        res.status(500).json({messsage:error.messsage});
    }
}

// ta sẽ tạo hàm lấy từng user theo id
export const getUserById = async ( req , res)=>{
    try{
        const user =await User.findById(req.params.id).select("-password");
        if (!user){
            return res.status(404).json({message:"Người dùng không tồn tại"});
            
        }
        res.json(user);
    }
    catch (error) {
    res.status(500).json({ message: error.message });
  }
}

// tạo hàm để cập nhật người
// export const updateUser = async (req, res) => {
//   try {
//     const updated = await User.findByIdAndUpdate(req.params.id, req.body, {
//       new: true,
//     }).select("-password");
//     if (!updated) return res.status(404).json({ message: "User không tồn tại" });
//     res.json(updated);
//   } catch (error) {
//     res.status(500).json({ message: error.message });
//   }
// };

export const updateUser = async (req, res) => {
  try {
    const user = await User.findById(req.params.id);
    if (!user) return res.status(404).json({ message: "User không tồn tại" });

    // Nếu có gửi password mới → hash lại
    if (req.body.password) {
      req.body.password = await bcrypt.hash(req.body.password, 10);
    }

    const updated = await User.findByIdAndUpdate(req.params.id, req.body, {
      new: true,
    }).select("-password");

    res.json({
      message: "Cập nhật người dùng thành công",
      user: updated,
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// tạo hàm Xóa user
export const deleteUser = async (req, res) => {
  try {
    const deleted = await User.findByIdAndDelete(req.params.id);
    if (!deleted) return res.status(404).json({ message: "User không tồn tại" });
    res.json({ message: "Đã xóa user thành công" });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};