/******************************************************************************
// File Name:       SoftValidationCriterionTest
// Summary:         Test class for SoftValidationCriterion
// Created On:      08/06/2021

// Modification Log: (Name - Change Summary - Initial)
====================
Konstantin Ermolenko - 08/06/2021 - created class
*******************************************************************************/

@IsTest
private class SoftValidationCriterionTest{

    @IsTest
    static void testSoftValidationCriterion(){
        //test init with invalid expression
        SoftValidationCriterion criterion;
        Boolean exceptionOccurred = false;

        try{
            criterion = new SoftValidationCriterion('Formula', '1 + 2)', '=', 'Static', '3');
        }
        catch(Exception ex){
            exceptionOccurred = true;
        }

        System.assertEquals(true, exceptionOccurred);

        //test evaluate with invalid expression
        criterion = new SoftValidationCriterion('Formula', 'NOW() * 3', '=', 'Static', '3');
        exceptionOccurred = false;

        try{
            criterion.evaluate(null, null, null);
        }
        catch(Exception ex){
            exceptionOccurred = true;
        }

        System.assertEquals(true, exceptionOccurred);

        //test evaluate with valid expressions
        criterion = new SoftValidationCriterion('Static', 'test', '=', 'Static', '1');
        System.assertEquals(false, criterion.evaluate(null, null, null));

        criterion = new SoftValidationCriterion('Static', 'test', '!=', 'Static', '1');
        System.assertEquals(true, criterion.evaluate(null, null, null));

        criterion = new SoftValidationCriterion('Static', '1', '=', 'Static', '1');
        System.assertEquals(true, criterion.evaluate(null, null, null));

        criterion = new SoftValidationCriterion('Static', '1', '!=', 'Static', '1.01');
        System.assertEquals(true, criterion.evaluate(null, null, null));

        criterion = new SoftValidationCriterion('Static', '1', '<', 'Static', '1');
        System.assertEquals(false, criterion.evaluate(null, null, null));

        criterion = new SoftValidationCriterion('Static', '1', '>', 'Static', '1');
        System.assertEquals(false, criterion.evaluate(null, null, null));

        criterion = new SoftValidationCriterion('Static', '1', '<=', 'Static', '1');
        System.assertEquals(true, criterion.evaluate(null, null, null));

        criterion = new SoftValidationCriterion('Static', '1', '>=', 'Static', '1');
        System.assertEquals(true, criterion.evaluate(null, null, null));

        criterion = new SoftValidationCriterion('Formula', 'TODAY()', '<', 'Formula', 'TODAY()');
        System.assertEquals(false, criterion.evaluate(null, null, null));

        criterion = new SoftValidationCriterion('Formula', 'TODAY()', '>', 'Formula', 'TODAY()');
        System.assertEquals(false, criterion.evaluate(null, null, null));

        criterion = new SoftValidationCriterion('Formula', 'TODAY()', '<=', 'Formula', 'TODAY()');
        System.assertEquals(true, criterion.evaluate(null, null, null));

        criterion = new SoftValidationCriterion('Formula', 'TODAY()', '>=', 'Formula', 'TODAY()');
        System.assertEquals(true, criterion.evaluate(null, null, null));

        criterion = new SoftValidationCriterion('Static', 'test', 'CONTAINS', 'Static', 'te');
        System.assertEquals(true, criterion.evaluate(null, null, null));

        criterion = new SoftValidationCriterion('Static', 'test', 'STARTS WITH', 'Static', 'te');
        System.assertEquals(true, criterion.evaluate(null, null, null));

        criterion = new SoftValidationCriterion('Static', 'test1;test2', 'INCLUDES', 'Static', 'test2');
        System.assertEquals(true, criterion.evaluate(null, null, null));

        //misc
        criterion.getFieldsForQuery(new Map<String, Set<String>>());
        criterion.getParsingResultsJSON();
        criterion.getEvaluationLog();
        SoftValidationCriterion.getOperatorShortcut('EQUALS');
    }
}