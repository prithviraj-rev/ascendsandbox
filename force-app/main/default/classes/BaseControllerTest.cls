/******************************************************************************
// File Name:       BaseControllerTest
// Summary:         Test class for BaseController
// Created On:      11/28/2024

// Modification Log: (Name - Change Summary - Initial)
====================
Roman Bulgakov - 11/28/2024 - created
*******************************************************************************/
@IsTest
private class BaseControllerTest {
    @IsTest
    static void test() {
        AuraHelper.Response response;
        Test.startTest();
        response = (AuraHelper.Response)BaseController.auraInvoke('BaseControllerTest.CallableTest', 'test', null);
        Test.stopTest();
        System.assertEquals('testComplete', (String)response.result);

        AbstractTrigger instance = new AbstractTrigger();
        instance.beforeInsert(null);
        instance.afterInsert(null);
        instance.beforeUpdate(null, null);
        instance.afterUpdate(null, null);
        instance.beforeDelete(null);
        instance.afterDelete(null);
    }

    public class CallableTest implements Callable
    {
    	public Object call(String actionName, Map<String, Object> params){
            return('testComplete');
        }
    }
}