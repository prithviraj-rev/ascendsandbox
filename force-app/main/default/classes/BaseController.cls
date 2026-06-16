/******************************************************************************
// Summary:         The class controller to handle AURA, LWC, VF components requests
// Test Class:      BaseControllerTest

// Modification Log: (Name - Change Summary - Initial)
====================
Roman Bulgakov - 05/30/2024 - created
*******************************************************************************/

public with sharing class BaseController {
    @AuraEnabled
    public static Object auraInvoke(String handlerName, String actionName, Map<String, Object> params) {
        return remoteInvoke(handlerName, actionName, params);
    }

	@RemoteAction
    public static Object remoteInvoke(String handlerName, String actionName, Map<String, Object> params) {
        try{
            Type instanceType = Type.forName(handlerName);
            if(instanceType == null) throw new AuraHelper.AuraException('Invalid handler name.'); 

            Callable instance = (Callable)instanceType.newInstance();
            if(instance == null) throw new AuraHelper.AuraException('Can not create instance of handler.'); 

            return new AuraHelper.Response(instance.call(actionName, params));
        }catch(Exception ex) {
            return new AuraHelper.Response(ex);
        }
    }
}