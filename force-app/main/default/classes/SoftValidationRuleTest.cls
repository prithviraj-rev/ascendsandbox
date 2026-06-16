/******************************************************************************
// File Name:       SoftValidationRuleTest
// Summary:         Test class for SoftValidationRule
// Created On:      08/06/2021

// Modification Log: (Name - Change Summary - Initial)
====================
Konstantin Ermolenko - 08/06/2021 - created class
*******************************************************************************/

@IsTest
private class SoftValidationRuleTest{

    @IsTest
    static void testSoftValidationRule(){
        //test init with invalid Logic Filter
        SoftValidationRule rule;
        Boolean exceptionOccurred = false;

        try{
            rule = new SoftValidationRule('test');
        }
        catch(Exception ex){
            exceptionOccurred = true;
        }

        System.assertEquals(true, exceptionOccurred);

        //test adding invalid criterion
        rule = new SoftValidationRule(null);
        exceptionOccurred = false;

        try{
            rule.addCriterion('Formula', '1 + 2)', 'Equals', 'Static', '3');
        }
        catch(Exception ex){
            exceptionOccurred = true;
        }

        System.assertEquals(true, exceptionOccurred);

        //test evaluate with incompatible data types for criterion
        rule.addCriterion('Formula', 'NOW()', 'Equals', 'Static', 'test');
        rule.addCriterion('Static', 'test', 'Equals', 'Static', 'test');
        exceptionOccurred = false;

        try{
            rule.evaluate(null, null, null);
        }
        catch(Exception ex){
            exceptionOccurred = true;
        }

        System.assertEquals(true, exceptionOccurred);

        //test evaluate with invalid Filter Logic:
        rule = new SoftValidationRule('1 OR 3');
        rule.addCriterion('Static', '1', 'Equals', 'Static', '1');
        exceptionOccurred = false;

        try{
            rule.evaluate(null, null, null);
        }
        catch(Exception ex){
            exceptionOccurred = true;
        }

        System.assertEquals(true, exceptionOccurred);

        //test evaluate with valid params:
        rule = new SoftValidationRule('1 OR 2');
        rule.addCriterion('Static', '1', 'Equals', 'Static', '1');
        rule.addCriterion('Static', '1', 'Equals', 'Static', '1');
        Boolean evalResult = rule.evaluate(null, null, null);

        System.assertEquals(true, evalResult);

        //misc
        rule.getCriteria();
        rule.getFieldsForQuery(null);
    }
}