/******************************************************************************
// File Name:       SoftValidationDebuggerControllerTest
// Summary:         Test class for SoftValidationDebuggerController
// Created On:      08/05/2021

// Modification Log: (Name - Change Summary - Initial)
====================
Konstantin Ermolenko - 08/05/2021 - created class
Konstantin Ermolenko - 10/28/2021 - added support for Merge Fields in Rule Message
*******************************************************************************/

@IsTest
private class SoftValidationDebuggerControllerTest{

    @IsTest
    static void testSoftValidationDebuggerController(){
        SoftValidationRuleHandler.disableValidation = true;

        SoftValidationRule__c rule = new SoftValidationRule__c();
        rule.Name = 'Test';
        rule.ObjectAPIName__c = 'SoftValidationRule__c';
        rule.Criteria1LeftExpressionType__c = 'Formula';
        rule.Criteria1LeftExpression__c = 'Name))'; //invalid expression
        rule.Criteria1Operator__c = 'Less Than';
        rule.Criteria1RightExpressionType__c = 'Formula';
        rule.Criteria1RightExpression__c = 'NOW()';
        rule.FilterLogic__c = '1';

        insert rule;

        Test.startTest();

        //test evaluate with generic exception
        AuraHelper.Response response = SoftValidationDebuggerController.evaluateRule(null);
        System.assertEquals(false, response.success);

        //test evaluate with "parse" exception
        response = SoftValidationDebuggerController.evaluateRule(new Map<String, Object>{
            'ruleId' => rule.Id,
            'recordId' => rule.Id
        });
        System.assertEquals(true, response.success);

        Map<String, Object> responseData = (Map<String, Object>) JSON.deserializeUntyped((String) response.result);
        Boolean successParse = (Boolean) responseData.get('successParse');
        System.assertEquals(false, successParse);

        //test evaluate with "evaluate" exception
        rule.Criteria1LeftExpression__c = 'Name';
        update rule;

        response = SoftValidationDebuggerController.evaluateRule(new Map<String, Object>{
            'ruleId' => rule.Id,
            'recordId' => rule.Id
        });
        System.assertEquals(true, response.success);

        responseData = (Map<String, Object>) JSON.deserializeUntyped((String) response.result);
        successParse = (Boolean) responseData.get('successParse');
        System.assertEquals(true, successParse);
        Boolean successEvaluate = (Boolean) responseData.get('successEvaluate');
        System.assertEquals(false, successEvaluate);

        //test "no message" error
        rule.Criteria1Operator__c = 'Equals';
        rule.Criteria1RightExpressionType__c = 'Static';
        rule.Criteria1RightExpression__c = 'Test';
        update rule;

        response = SoftValidationDebuggerController.evaluateRule(new Map<String, Object>{
            'ruleId' => rule.Id,
            'recordId' => rule.Id
        });
        System.assertEquals(true, response.success);

        responseData = (Map<String, Object>) JSON.deserializeUntyped((String) response.result);
        successParse = (Boolean) responseData.get('successParse');
        System.assertEquals(true, successParse);
        successEvaluate = (Boolean) responseData.get('successEvaluate');
        System.assertEquals(true, successEvaluate);
        Boolean messageSuccessParse = (Boolean) responseData.get('messageSuccessParse');
        System.assertEquals(false, messageSuccessParse);
        Boolean messageSuccessEvaluate = (Boolean) responseData.get('messageSuccessEvaluate');
        System.assertEquals(false, messageSuccessEvaluate);

        //test success
        rule.MessageType__c = 'Info';
        rule.Message__c = 'test';
        update rule;

        response = SoftValidationDebuggerController.evaluateRule(new Map<String, Object>{
            'ruleId' => rule.Id,
            'recordId' => rule.Id
        });
        System.assertEquals(true, response.success);

        responseData = (Map<String, Object>) JSON.deserializeUntyped((String) response.result);
        successParse = (Boolean) responseData.get('successParse');
        System.assertEquals(true, successParse);
        successEvaluate = (Boolean) responseData.get('successEvaluate');
        System.assertEquals(true, successEvaluate);
        messageSuccessParse = (Boolean) responseData.get('messageSuccessParse');
        System.assertEquals(true, messageSuccessParse);
        messageSuccessEvaluate = (Boolean) responseData.get('messageSuccessEvaluate');
        System.assertEquals(true, messageSuccessEvaluate);

        //test evaluate Message with "parse" exception
        rule.Message__c = '{!test';
        update rule;

        response = SoftValidationDebuggerController.evaluateRule(new Map<String, Object>{
            'ruleId' => rule.Id,
            'recordId' => rule.Id
        });
        System.assertEquals(true, response.success);

        responseData = (Map<String, Object>) JSON.deserializeUntyped((String) response.result);
        messageSuccessParse = (Boolean) responseData.get('messageSuccessParse');
        System.assertEquals(false, messageSuccessParse);

        //test evaluate Message with "evaluate" exception
        rule.Message__c = '{!"test" & NOW()}'.escapeHtml4();
        update rule;

        response = SoftValidationDebuggerController.evaluateRule(new Map<String, Object>{
            'ruleId' => rule.Id,
            'recordId' => rule.Id
        });
        System.assertEquals(true, response.success);

        responseData = (Map<String, Object>) JSON.deserializeUntyped((String) response.result);
        messageSuccessParse = (Boolean) responseData.get('messageSuccessParse');
        System.assertEquals(true, messageSuccessParse);
        messageSuccessEvaluate = (Boolean) responseData.get('messageSuccessEvaluate');
        System.assertEquals(false, messageSuccessEvaluate);

        Test.stopTest();
    }
}