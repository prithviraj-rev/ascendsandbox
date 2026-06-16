/******************************************************************************
// File Name:       SoftValidationUtilsTest
// Summary:         Test class for SoftValidationUtils
// Created On:      08/05/2021

// Modification Log: (Name - Change Summary - Initial)
====================
Konstantin Ermolenko - 08/05/2021 - created class
*******************************************************************************/

@IsTest
private class SoftValidationUtilsTest{

    @IsTest
    static void testSoftValidationUtils(){
        //test findClosingCharacterIndex
        Integer closingCharIndex = SoftValidationUtils.findClosingCharacterIndex('"test")', '(', ')');
        System.assertEquals(6, closingCharIndex);

        //test validateFieldExpressionSoft
        Map<String, Object> validateFieldExpressionSoftResult = SoftValidationUtils.validateFieldExpressionSoft('.');
        System.assertEquals(false, validateFieldExpressionSoftResult.get('isValid'));

        validateFieldExpressionSoftResult = SoftValidationUtils.validateFieldExpressionSoft('Account..Name');
        System.assertEquals(false, validateFieldExpressionSoftResult.get('isValid'));

        validateFieldExpressionSoftResult = SoftValidationUtils.validateFieldExpressionSoft('1test');
        System.assertEquals(false, validateFieldExpressionSoftResult.get('isValid'));

        validateFieldExpressionSoftResult = SoftValidationUtils.validateFieldExpressionSoft('1test');
        System.assertEquals(false, validateFieldExpressionSoftResult.get('isValid'));

        validateFieldExpressionSoftResult = SoftValidationUtils.validateFieldExpressionSoft('Account.Test__r');
        System.assertEquals(false, validateFieldExpressionSoftResult.get('isValid'));

        validateFieldExpressionSoftResult = SoftValidationUtils.validateFieldExpressionSoft('Account__c.Test__c');
        System.assertEquals(false, validateFieldExpressionSoftResult.get('isValid'));

        validateFieldExpressionSoftResult = SoftValidationUtils.validateFieldExpressionSoft('Account__c.Test__c');
        System.assertEquals(false, validateFieldExpressionSoftResult.get('isValid'));

        validateFieldExpressionSoftResult = SoftValidationUtils.validateFieldExpressionSoft('Account___c');
        System.assertEquals(false, validateFieldExpressionSoftResult.get('isValid'));

        validateFieldExpressionSoftResult = SoftValidationUtils.validateFieldExpressionSoft('Acco___unt__c');
        System.assertEquals(false, validateFieldExpressionSoftResult.get('isValid'));

        validateFieldExpressionSoftResult = SoftValidationUtils.validateFieldExpressionSoft('Acc$ount__c');
        System.assertEquals(false, validateFieldExpressionSoftResult.get('isValid'));

        validateFieldExpressionSoftResult = SoftValidationUtils.validateFieldExpressionSoft('Account.Contact__r.Name');
        System.assertEquals(true, validateFieldExpressionSoftResult.get('isValid'));

        //test registerFieldForQuery
        Map<String, Set<String>> fieldsForQuery = new Map<String, Set<String>>();
        SoftValidationUtils.registerFieldForQuery(fieldsForQuery, 'Account', 'Name');
        System.assertEquals(true, fieldsForQuery.containsKey('Account'));
        System.assertEquals(true, fieldsForQuery.get('Account').contains('Name'));

        //test getFieldValue
        Opportunity opp = new Opportunity();
        opp.putSObject('Account', new Account(Name = 'Test', AnnualRevenue = 1));
        SoftValidationUtils.SoftValidationFieldValue fieldValue = SoftValidationUtils.getFieldValue(opp, 'Account.Name');
        System.assertEquals('Test', fieldValue.value);

        fieldValue = SoftValidationUtils.getFieldValue(opp, 'Account.AnnualRevenue');
        System.assertEquals(1, fieldValue.value);

        fieldValue = SoftValidationUtils.getFieldValue(opp, 'Account.IsPartner');

        //test getFieldTypeRecursive
        SoftValidationUtils.SoftValidationFieldTypeDetails fieldTypeDetails = SoftValidationUtils.getFieldTypeRecursive(opp.getSObjectType(), 'Account.Name');
        System.assertEquals('STRING', fieldTypeDetails.type);
    }
}