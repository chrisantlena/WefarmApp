<?php
// reset_password.php - Halaman web untuk reset password (clean version)

require_once 'db_config.php';

// Set timezone Indonesia
date_default_timezone_set('Asia/Jakarta');

function sanitize($data) {
    $data = trim($data);
    $data = stripslashes($data);
    $data = htmlspecialchars($data);
    return $data;
}

$message = '';
$error = '';
$token = '';
$validToken = false;
$tokenData = null;

// Cek token dari URL
if (isset($_GET['token'])) {
    $token = sanitize($_GET['token']);
    
    try {
        $conn = getConnection();
        
        // Verifikasi token di tabel users
        $stmt = $conn->prepare("
            SELECT id, email, username, reset_token_expires 
            FROM users 
            WHERE reset_token = ? AND reset_token_expires > CURRENT_TIMESTAMP
        ");
        $stmt->bind_param("s", $token);
        $stmt->execute();
        $result = $stmt->get_result();
        
        if ($result->num_rows > 0) {
            $validToken = true;
            $tokenData = $result->fetch_assoc();
        } else {
            $error = 'Invalid or expired reset token.';
        }
        
        $stmt->close();
        $conn->close();
        
    } catch (Exception $e) {
        $error = 'Database error: ' . $e->getMessage();
    }
} else {
    $error = 'Reset token is required.';
}

// Proses form submission
if ($_SERVER['REQUEST_METHOD'] === 'POST' && $validToken) {
    $newPassword = $_POST['password'] ?? '';
    $confirmPassword = $_POST['confirm_password'] ?? '';
    
    if (empty($newPassword) || empty($confirmPassword)) {
        $error = 'Please fill in all fields.';
    } elseif (strlen($newPassword) < 6) {
        $error = 'Password must be at least 6 characters long.';
    } elseif ($newPassword !== $confirmPassword) {
        $error = 'Passwords do not match.';
    } else {
        try {
            $conn = getConnection();
            
            // Hash password baru
            $hashedPassword = password_hash($newPassword, PASSWORD_DEFAULT);
            
            // Update password dan hapus token reset
            $stmt = $conn->prepare("
                UPDATE users 
                SET password = ?, reset_token = NULL, reset_token_expires = NULL 
                WHERE id = ?
            ");
            $stmt->bind_param("si", $hashedPassword, $tokenData['id']);
            $stmt->execute();
            
            $message = 'Password has been reset successfully! You can now login with your new password.';
            $validToken = false; // Hide form after successful reset
            
            $stmt->close();
            $conn->close();
            
        } catch (Exception $e) {
            $error = 'Error updating password: ' . $e->getMessage();
        }
    }
}
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reset Password - WeFarm</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background-color: #f5f5f5;
            margin: 0;
            padding: 20px;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
        }
        .container {
            background-color: white;
            padding: 40px;
            border-radius: 10px;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
            max-width: 400px;
            width: 100%;
        }
        .logo {
            text-align: center;
            margin-bottom: 30px;
        }
        .logo h1 {
            color: #f5bd52;
            margin: 0;
            font-size: 28px;
        }
        .form-group {
            margin-bottom: 20px;
        }
        label {
            display: block;
            margin-bottom: 5px;
            font-weight: bold;
            color: #333;
        }
        input[type="password"] {
            width: 100%;
            padding: 12px;
            border: 1px solid #ddd;
            border-radius: 5px;
            font-size: 16px;
            box-sizing: border-box;
        }
        input[type="password"]:focus {
            outline: none;
            border-color: #f5bd52;
        }
        .btn {
            width: 100%;
            padding: 12px;
            background-color: #f5bd52;
            color: white;
            border: none;
            border-radius: 5px;
            font-size: 16px;
            cursor: pointer;
            font-weight: bold;
        }
        .btn:hover {
            background-color: #e6a545;
        }
        .message {
            padding: 15px;
            border-radius: 5px;
            margin-bottom: 20px;
            text-align: center;
        }
        .success {
            background-color: #d4edda;
            color: #155724;
            border: 1px solid #c3e6cb;
        }
        .error {
            background-color: #f8d7da;
            color: #721c24;
            border: 1px solid #f5c6cb;
        }
        .info {
            text-align: center;
            color: #666;
            margin-bottom: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">
            <h1>WeFarm</h1>
        </div>
        
        <?php if ($message): ?>
            <div class="message success">
                <?php echo $message; ?>
            </div>
        <?php endif; ?>
        
        <?php if ($error): ?>
            <div class="message error">
                <?php echo $error; ?>
            </div>
        <?php endif; ?>
        
        <?php if ($validToken): ?>
            <div class="info">
                <p>Hello <?php echo htmlspecialchars($tokenData['username']); ?>!</p>
                <p>Please enter your new password below:</p>
            </div>
            
            <form method="POST" action="">
                <div class="form-group">
                    <label for="password">New Password:</label>
                    <input type="password" id="password" name="password" required minlength="6">
                </div>
                
                <div class="form-group">
                    <label for="confirm_password">Confirm New Password:</label>
                    <input type="password" id="confirm_password" name="confirm_password" required minlength="6">
                </div>
                
                <button type="submit" class="btn">Reset Password</button>
            </form>
        <?php endif; ?>
        
        <?php if ($message): ?>
            <div style="text-align: center; margin-top: 20px;">
                <p>You can now close this window and return to the app to login.</p>
            </div>
        <?php endif; ?>
    </div>
</body>
</html>