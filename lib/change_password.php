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
    if (empty($data['user_id']) || empty($data['current_password']) || empty($data['new_password'])) {
        throw new Exception('Missing required fields');
    }

    // Validate new password length
    if (strlen($data['new_password']) < 6) {
        throw new Exception('New password must be at least 6 characters long');
    }

    // Database connection
    $servername = "localhost";
    $username = "root";
    $password = "";
    $dbname = "wefarm";

    $conn = new mysqli($servername, $username, $password, $dbname);

    if ($conn->connect_error) {
        throw new Exception("Connection failed: " . $conn->connect_error);
    }

    // Get current user data
    $getUserStmt = $conn->prepare("SELECT password FROM users WHERE id = ?");
    $getUserStmt->bind_param("s", $data['user_id']);
    $getUserStmt->execute();
    $userResult = $getUserStmt->get_result();

    if ($userResult->num_rows === 0) {
        throw new Exception('User not found');
    }

    $user = $userResult->fetch_assoc();

    // Verify current password
    if (!password_verify($data['current_password'], $user['password'])) {
        throw new Exception('Current password is incorrect');
    }

    // Hash new password
    $hashedNewPassword = password_hash($data['new_password'], PASSWORD_DEFAULT);

    // Update password
    $updateStmt = $conn->prepare("UPDATE users SET password = ? WHERE id = ?");
    $updateStmt->bind_param("ss", $hashedNewPassword, $data['user_id']);

    if ($updateStmt->execute() && $updateStmt->affected_rows > 0) {
        echo json_encode([
            'success' => true,
            'message' => 'Password changed successfully'
        ]);
    } else {
        throw new Exception('Failed to update password');
    }

    $updateStmt->close();
    $getUserStmt->close();
    $conn->close();

} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
?>