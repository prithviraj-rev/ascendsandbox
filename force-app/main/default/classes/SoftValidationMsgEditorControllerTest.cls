/******************************************************************************
// File Name:       SoftValidationMsgEditorControllerTest
// Summary:         Test class for SoftValidationMsgEditorController
// Created On:      11/03/2021

// Modification Log: (Name - Change Summary - Initial)
====================
Konstantin Ermolenko - 11/03/2021 - created class
*******************************************************************************/

@IsTest
private class SoftValidationMsgEditorControllerTest{

    @IsTest
    static void testSoftValidationMsgEditorController(){
        SoftValidationRuleHandler.disableValidation = true;
        SoftValidationRule__c rule = new SoftValidationRule__c(ObjectAPIName__c = 'Account');
        insert rule;
        SoftValidationRuleHandler.disableValidation = false;

        Test.startTest();

        AuraHelper.Response r = SoftValidationMsgEditorController.loadRule(rule.Id);
        System.assertEquals(true, r.success);

        //negative scenario - merge fields in Message are not valid
        Map<String, Object> params = new Map<String, Object>{
            'ruleId' => rule.Id,
            'messageType' => 'Custom',
            'message' => '{!Name' //missing closing curly bracket
        };

        r = SoftValidationMsgEditorController.saveRule(params);
        System.assertEquals(false, r.success);

        //positive scenario
        params.put('message', '{!Name}');
        r = SoftValidationMsgEditorController.saveRule(params);
        System.assertEquals(true, r.success);

        Test.stopTest();
    }
}