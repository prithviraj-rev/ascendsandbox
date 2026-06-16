/******************************************************************************
// File Name:       QueueServiceTest
// Summary:         Test class for QueueService
// Created On:      11/28/2024

// Modification Log: (Name - Change Summary - Initial)
====================
Roman Bulgakov - 11/28/2024 - created
*******************************************************************************/
@IsTest
private class QueueServiceTest {
    @IsTest
    static void test() {
        new QueueService();
        QueueService.start('key', 'data', 'QueueServiceTest.CallableTest');
    }

    public class CallableTest implements Callable {
    	public Object call(String actionName, Map<String, Object> params) {
            return null;
        }
    }
}