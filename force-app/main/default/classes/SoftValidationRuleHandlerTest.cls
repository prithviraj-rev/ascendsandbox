/******************************************************************************
// File Name:       SoftValidationRuleHandlerTest
// Summary:         Test class for SoftValidationRuleHandler
// Created On:      08/05/2021

// Modification Log: (Name - Change Summary - Initial)
====================
Konstantin Ermolenko - 08/05/2021 - created class
Konstantin Ermolenko - 10/28/2021 - added support for Merge Fields in Rule Message
Konstantin Ermolenko - 10/28/2021 - added "testSoftValidationRuleMessageSave" method
*******************************************************************************/

@IsTest
private class SoftValidationRuleHandlerTest{

    @IsTest
    static void testSoftValidationRuleCreation(){
        SoftValidationRule__c rule = new SoftValidationRule__c(Name = 'Test', MessageType__c = 'Info');

        //test insert with invalid Object Name
        rule.ObjectAPIName__c = 'Opportunity123';
        assertRuleInsert(rule, true, 'Expected insert to fail: invalid object name.');

        //test insert with RT populated, but Object does not have RTs
        rule.ObjectAPIName__c = 'SoftValidationRule__c';
        rule.RecordTypeDevName__c = 'Test';
        assertRuleInsert(rule, true, 'Expected insert to fail: object does not have Record Types.');

        //test insert with invalid RT
        rule.ObjectAPIName__c = 'Opportunity';
        rule.RecordTypeDevName__c = 'Test';
        assertRuleInsert(rule, true, 'Expected insert to fail: invalid Record Type.');

        //test insert with Criterion blank fields
        rule.RecordTypeDevName__c = null;
        rule.Criteria1LeftExpression__c = 'test'; //other Criteria1 fields are blank, so the exception will be thrown
        assertRuleInsert(rule, true, 'Expected insert to fail: criterion with blank fields.');

        //test insert with gaps between Criteria
        rule.Criteria1LeftExpressionType__c = 'Static';
        rule.Criteria1LeftExpression__c = 'test';
        rule.Criteria1Operator__c = 'Equals';
        rule.Criteria1RightExpressionType__c = 'Static';
        rule.Criteria1RightExpression__c = 'test';

        rule.Criteria3LeftExpressionType__c = 'Static';
        rule.Criteria3LeftExpression__c = 'test';
        rule.Criteria3Operator__c = 'Equals';
        rule.Criteria3RightExpressionType__c = 'Static';
        rule.Criteria3RightExpression__c = 'test';
        assertRuleInsert(rule, true, 'Expected insert to fail: gaps between Criteria.');

        //test insert with invalid Filter Logic
        rule.Criteria2LeftExpressionType__c = 'Static';
        rule.Criteria2LeftExpression__c = 'test';
        rule.Criteria2Operator__c = 'Equals';
        rule.Criteria2RightExpressionType__c = 'Static';
        rule.Criteria2RightExpression__c = 'test';

        rule.Criteria3LeftExpression__c = null;
        rule.Criteria3RightExpression__c = null;

        rule.FilterLogic__c = 'test';
        assertRuleInsert(rule, true, 'Expected insert to fail: invalid Filter Logic.');

        //test insert with invalid Filter Logic - Criterion number is out of bounds
        rule.FilterLogic__c = '1 OR 20';
        assertRuleInsert(rule, true, 'Expected insert to fail: invalid Filter Logic - Criterion number is out of bounds.');

        //test insert with invalid Filter Logic - Criterion is not configured
        rule.FilterLogic__c = '1 OR 5';
        assertRuleInsert(rule, true, 'Expected insert to fail: invalid Filter Logic - Criterion is not configured.');

        //test insert with invalid Filter Logic - Criterion is not referenced
        rule.FilterLogic__c = '1 OR 1';
        assertRuleInsert(rule, true, 'Expected insert to fail: invalid Filter Logic - Criterion is not referenced.');

        //test insert with invalid formula expression
        rule.FilterLogic__c = null;
        rule.Criteria1LeftExpressionType__c = 'Formula';
        rule.Criteria1LeftExpression__c = 'test))';
        assertRuleInsert(rule, true, 'Expected insert to fail: invalid formula expression.');

        //test insert with invalid formula expression - field does not exist
        rule.Criteria1LeftExpressionType__c = 'Field';
        rule.Criteria1LeftExpression__c = 'Test';
        assertRuleInsert(rule, true, 'Expected insert to fail: field does not exist.');

        //test insert with invalid formula expression - unsupported field type
        rule.Criteria1LeftExpression__c = 'Account.BillingAddress';
        assertRuleInsert(rule, true, 'Expected insert to fail: unsupported field type.');

        //test insert with invalid Merge Field - missing closing bracket
        rule.Criteria1LeftExpression__c = 'Account.Name';
        rule.Message__c = '{!test';
        assertRuleInsert(rule, true, 'Expected insert to fail: missing closing bracket (Merge Field).');

        //test insert with invalid Merge Field - unsupported field type
        rule.Message__c = '{!Account.BillingAddress}';
        assertRuleInsert(rule, true, 'Expected insert to fail: unsupported field type (Merge Field).');

        //test successful insert
        rule.Message__c = '{!Account.Name}';
        assertRuleInsert(rule, false, 'Expected insert to succeed.');

        Test.startTest();

        //test with Filter Logic populated
        SoftValidationRule__c rule2 = rule.clone(false, true, false, false);
        rule2.FilterLogic__c = '1 OR 2';
        insert rule2;

        //cover empty ITrigger methods
        rule2.Name = 'Test2';
        update rule2;

        delete rule2;
        undelete rule2;

        Test.stopTest();
    }

    @IsTest
    static void testSoftValidationRuleMessageSave(){
        SoftValidationRuleHandler.isMessageSave = true;
        SoftValidationRule__c rule = new SoftValidationRule__c(Name = 'Test');

        //test insert with invalid Object Name
        rule.ObjectAPIName__c = 'Opportunity123';
        assertRuleInsert(rule, true, 'Expected insert to fail: invalid object name.');

        //test insert with blank Message Type
        rule.ObjectAPIName__c = 'Opportunity';
        rule.MessageType__c = null;
        assertRuleInsert(rule, true, 'Expected insert to fail: Message Type is not populated.');

        //test insert with blank Message
        rule.MessageType__c = 'Info';
        rule.Message__c = null;
        assertRuleInsert(rule, true, 'Expected insert to fail: Message is not populated.');

        //test insert with invalid Merge Field - missing closing bracket
        rule.Message__c = '{!test';
        assertRuleInsert(rule, true, 'Expected insert to fail: missing closing bracket (Merge Field).');

        //test insert with invalid Merge Field - unsupported field type
        rule.Message__c = '{!Account.BillingAddress}';
        assertRuleInsert(rule, true, 'Expected insert to fail: unsupported field type (Merge Field).');

        //test successful insert
        rule.Message__c = '{!Account.Name}';
        assertRuleInsert(rule, false, 'Expected insert to succeed.');
    }

    private static void assertRuleInsert(SoftValidationRule__c rule, Boolean insertFailed, String assertMsg){
        Boolean exceptionWasThrown = false;

        try{
            insert rule;
        }
        catch (Exception ex){
            exceptionWasThrown = true;
        }

        System.assert(exceptionWasThrown == insertFailed, assertMsg);
    }
}