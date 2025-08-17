<?php
error_reporting(0);
ini_set('display_errors', 0);

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit(0);
}

$servername = "localhost";
$username = "root";
$password = "";
$dbname = "wefarm";

try {
    $pdo = new PDO("mysql:host=$servername;dbname=$dbname", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch(PDOException $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Database connection failed']);
    exit();
}

$method = $_SERVER['REQUEST_METHOD'];

switch($method) {
    case 'POST':
        $input = json_decode(file_get_contents('php://input'), true);
        
        if (!isset($input['user_id']) || !isset($input['plant_id']) || !isset($input['name'])) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'Missing required fields']);
            exit();
        }
        
        try {
            $pdo->beginTransaction();
            
            $checkStmt = $pdo->prepare("SELECT id FROM user_plants WHERE user_id = ? AND plant_id = ? AND status = 'tracking'");
            $checkStmt->execute([$input['user_id'], $input['plant_id']]);
            
            if ($checkStmt->fetch()) {
                $pdo->rollBack();
                http_response_code(400);
                echo json_encode(['success' => false, 'message' => 'Plant already being tracked']);
                exit();
            }
            
            $stmt = $pdo->prepare("INSERT INTO user_plants (user_id, plant_id, name, start_date, status, progress) VALUES (?, ?, ?, NOW(), 'tracking', 0.0)");
            $stmt->execute([$input['user_id'], $input['plant_id'], $input['name']]);
            
            $trackerId = $pdo->lastInsertId();
            
            $getStmt = $pdo->prepare("
                SELECT up.*, p.duration, p.image_path, p.guide 
                FROM user_plants up 
                JOIN plants p ON up.plant_id = p.id 
                WHERE up.id = ?
            ");
            $getStmt->execute([$trackerId]);
            $result = $getStmt->fetch(PDO::FETCH_ASSOC);
            
            $pdo->commit();
            
            if (ob_get_length()) {
                ob_clean();
            }
            
            http_response_code(201);
            echo json_encode([
                'success' => true, 
                'message' => 'Plant tracking started successfully',
                'data' => $result
            ]);
            
        } catch(PDOException $e) {
            $pdo->rollBack();
            http_response_code(500);
            echo json_encode(['success' => false, 'message' => 'Database error']);
        }
        break;
        
    case 'GET':
        if (!isset($_GET['user_id'])) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'user_id required']);
            exit();
        }
        
        try {
            $statusFilter = isset($_GET['status']) ? $_GET['status'] : null;
            
            $query = "
                SELECT up.*, p.name as plant_name, p.duration, p.image_path, p.guide
                FROM user_plants up 
                JOIN plants p ON up.plant_id = p.id 
                WHERE up.user_id = ?
            ";
            
            $params = [$_GET['user_id']];
            
            if ($statusFilter) {
                $query .= " AND up.status = ?";
                $params[] = $statusFilter;
            } else {
                $query .= " ORDER BY 
                    CASE WHEN up.status = 'tracking' THEN 0 ELSE 1 END,
                    up.start_date DESC";
            }
            
            $stmt = $pdo->prepare($query);
            $stmt->execute($params);
            $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            echo json_encode(['success' => true, 'data' => $results]);
            
        } catch(PDOException $e) {
            http_response_code(500);
            echo json_encode(['success' => false, 'message' => 'Database error']);
        }
        break;
            
case 'PUT':
    $input = json_decode(file_get_contents('php://input'), true);
    
    // ✅ DEBUG LOG - LIAT APA YANG MASUK
    error_log("PUT Request received: " . json_encode($input));
    
    if (!isset($input['tracker_id'])) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'tracker_id required']);
        exit();
    }
    
    try {
        $updateFields = [];
        $params = [];
        
        if (isset($input['progress'])) {
            $updateFields[] = "progress = ?";
            $params[] = floatval($input['progress']);
        }
        
        if (isset($input['status'])) {
            $updateFields[] = "status = ?";
            $params[] = $input['status'];
            
            if (in_array($input['status'], ['completed', 'canceled', 'failed'])) {
                $updateFields[] = "end_date = NOW()";
            }
        }
        
        if (isset($input['end_date'])) {
            $updateFields[] = "end_date = ?";
            $params[] = $input['end_date'];
        }
        
        // ✅ NOTES - HANYA USER NOTES!
        if (isset($input['notes'])) {
            $updateFields[] = "notes = ?";
            $params[] = $input['notes'];
        }
        
        // ✅ TARGET DATA KE FIELD TERPISAH
        if (isset($input['completed_targets'])) {
            $updateFields[] = "completed_targets = ?";
            $params[] = json_encode($input['completed_targets']);
            error_log("Saving completed_targets: " . json_encode($input['completed_targets']));
        }
        
        if (isset($input['target_problems'])) {
            $updateFields[] = "target_problems = ?";
            $params[] = json_encode($input['target_problems']);
            error_log("Saving target_problems: " . json_encode($input['target_problems']));
        }
        
        if (empty($updateFields)) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'No fields to update']);
            exit();
        }
        
        $params[] = intval($input['tracker_id']);
        $sql = "UPDATE user_plants SET " . implode(', ', $updateFields) . " WHERE id = ?";
        
        error_log("SQL Query: $sql");
        error_log("Parameters: " . json_encode($params));
        
        $stmt = $pdo->prepare($sql);
        $result = $stmt->execute($params);
        
        if ($result && $stmt->rowCount() > 0) {
            echo json_encode(['success' => true, 'message' => 'Plant updated successfully']);
        } else {
            echo json_encode(['success' => false, 'message' => 'No rows updated or plant not found']);
        }
        
    } catch(PDOException $e) {
        error_log("Database error: " . $e->getMessage());
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Database error: ' . $e->getMessage()]);
    }
    break;
        
    default:
        http_response_code(405);
        echo json_encode(['success' => false, 'message' => 'Method not allowed']);
        break;
}
?>