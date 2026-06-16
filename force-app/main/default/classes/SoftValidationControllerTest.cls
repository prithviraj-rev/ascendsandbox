/******************************************************************************
// File Name:       SoftValidationControllerTest
// Summary:         Test class for SoftValidationController
// Created On:      08/05/2021

// Modification Log: (Name - Change Summary - Initial)
====================
Konstantin Ermolenko - 08/05/2021 - created class
*******************************************************************************/

@IsTest
private class SoftValidationControllerTest{

    @IsTest
    static void testSoftValidationController(){
        SoftValidationRule__c rule = new SoftValidationRule__c();
        rule.Name = 'Test';
        rule.MessageType__c = 'Info';
        rule.ObjectAPIName__c = 'SoftValidationRule__c';
        rule.Message__c = 'test';
        rule.Criteria1LeftExpressionType__c = 'Field';
        rule.Criteria1LeftExpression__c = 'Name';
        rule.Criteria1Operator__c = 'Equals';
        rule.Criteria1RightExpressionType__c = 'Static';
        rule.Criteria1RightExpression__c = 'Test';
        insert rule;

        Test.startTest();

        AuraHelper.Response response = SoftValidationController.getRulesQualifiedForEvaluation(new Map<String, Object>{
            'recordId' => rule.Id
        });

        System.assertEquals(true, response.success);
        Map<String, Object> result = (Map<String, Object>) response.result;
        List<Object> rules = (List<Object>) result.get('rules');
        System.assertEquals(1, rules.size());

        //send invalid Id to cause exception
        response = SoftValidationController.getRulesQualifiedForEvaluation(new Map<String, Object>{
            'recordId' => '123'
        });
        System.assertEquals(false, response.success);

        Map<String, Object> evalParams = new Map<String, Object>{
            'recordId' => rule.Id,
            'sObjectName' => 'SoftValidationRule__c',
            'rulesJSON' => JSON.serialize(new List<Map<String, Object>>{new Map<String, Object>{'id' => rule.Id}})
        };

        response = SoftValidationController.evaluateRules(evalParams);
        System.assertEquals(true, response.success);
        result = (Map<String, Object>) response.result;
        System.assertEquals(result.containsKey(rule.Id), true); //if rule got in the response, then it means it's qualified (or an error occurred)
        Map<String, Object> responseRule = (Map<String, Object>) result.get(rule.Id);
        System.assertEquals(responseRule.get('success'), true);

        //invalidate rule
        rule.Criteria1Operator__c = 'Less Than';
        rule.Criteria1RightExpressionType__c = 'Formula';
        rule.Criteria1RightExpression__c = 'NOW()'; //now types are incompatible
        update rule;

        response = SoftValidationController.evaluateRules(evalParams);
        System.assertEquals(true, response.success);
        result = (Map<String, Object>) response.result;
        System.assertEquals(result.containsKey(rule.Id), true); //if rule got in the response, then it means it's qualified (or an error occurred)
        responseRule = (Map<String, Object>) result.get(rule.Id);
        System.assertEquals(responseRule.get('success'), false);

        //send invalid input params:
        response = SoftValidationController.evaluateRules(new Map<String, Object>{
            'recordId' => '123',
            'sObjectName' => 'SoftValidationRule__c',
            'rulesJSON' => 'test'
        });
        System.assertEquals(false, response.success);

        Test.stopTest();
    }
}