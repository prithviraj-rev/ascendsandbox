/******************************************************************************
// File Name:       AbstractLookupControllerTest
// Summary:         Test class for AbstractLookupController
// Created On:      11/28/2024

// Modification Log: (Name - Change Summary - Initial)
====================
Roman Bulgakov - 11/28/2024 - created
*******************************************************************************/
@IsTest
private class AbstractLookupControllerTest {
    @IsTest
    static void test() {
        List<Object> result = (List<Object>)new AbstractLookupController().call('search', new Map<String, Object>{'objectName' =>'User','valueField' => 'id','value' => '','searchField' => 'Name','searchValue' => UserInfo.getName(),'conditions' => '','limitValue' => '1','searchClass' => ''});
        result = (List<Object>)new AbstractLookupController().call('search', new Map<String, Object>{'objectName' =>'User','valueField' => 'id','value' => UserInfo.getUserId(),'searchField' => '','searchValue' => '','conditions' => '','limitValue' => '1','searchClass' => ''});
    
        Boolean exc = false;
        try {
            new AbstractLookupController().call('invalid', null);
        }catch(Exception ex){
            exc = true;
            System.assertEquals('Invalid action name.', ex.getMessage());
        }
        System.assert(exc);
        
        new AbstractLookupController().call('search', new Map<String, Object>{'searchClass' => 'AbstractLookupControllerTest.CallableTest', 'objectName' =>'','valueField' => '','value' => '','searchField' => '','searchValue' => '','conditions' => '','limitValue' => ''});  
    }

    public class CallableTest implements Callable
    {
    	public Object call(String actionName, Map<String, Object> params){return null;}
    }
}