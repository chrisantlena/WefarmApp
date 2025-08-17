<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

try {
    // Get JSON input
    $json = file_get_contents('php://input');
    $data = json_decode($json, true);

    if (!$data) {
        throw new Exception('Invalid JSON data');
    }

    // Validate required fields
    if (empty($data['user_id']) || empty($data['name']) || empty($data['email'])) {
        throw new Exception('Missing required fields: user_id, name, email');
    }

    // Database connection - SESUAI DENGAN CONFIG YANG WORKING
    $servername = "localhost";
    $username = "root";
    $password = "";
    $dbname = "wefarm"; // ✅ CONFIRMED WORKING dari test

    $conn = new mysqli($servername, $username, $password, $dbname);

    if ($conn->connect_error) {
        throw new Exception("Connection failed: " . $conn->connect_error);
    }

    // ✅ FIX: Check if user exists first (seperti update_basic.php yang working)
    $checkUserStmt = $conn->prepare("SELECT id FROM users WHERE id = ?");
    $checkUserStmt->bind_param("s", $data['user_id']);
    $checkUserStmt->execute();
    $userResult = $checkUserStmt->get_result();

    if ($userResult->num_rows === 0) {
        throw new Exception('User not found with ID: ' . $data['user_id']);
    }

    // Check if email already exists for other users
    $checkEmailStmt = $conn->prepare("SELECT id FROM users WHERE email = ? AND id != ?");
    $checkEmailStmt->bind_param("ss", $data['email'], $data['user_id']);
    $checkEmailStmt->execute();
    $emailResult = $checkEmailStmt->get_result();

    if ($emailResult->num_rows > 0) {
        throw new Exception('Email already exists');
    }

    // ✅ FIX: Update user profile - SESUAI STRUKTUR DATABASE (username, bukan name)
    $updateStmt = $conn->prepare("UPDATE users SET username = ?, email = ?, phone = ?, address = ? WHERE id = ?");
    $updateStmt->bind_param("sssss", 
        $data['name'],     // Flutter 'name' -> database 'username' 
        $data['email'], 
        $data['phone'], 
        $data['address'], 
        $data['user_id']
    );

    if ($updateStmt->execute()) {
        // ✅ FIX: Always return success (like update_basic.php)
        // Karena affected_rows bisa 0 kalau data sama, tapi itu bukan error
        echo json_encode([
            'success' => true,
            'message' => 'Profile updated successfully'
        ]);
    } else {
        throw new Exception('Failed to update profile: ' . $updateStmt->error);
    }

    $updateStmt->close();
    $checkEmailStmt->close();
    $checkUserStmt->close();
    $conn->close();

} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
?>