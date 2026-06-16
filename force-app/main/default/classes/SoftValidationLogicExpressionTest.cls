/******************************************************************************
// File Name:       SoftValidationLogicExpressionTest
// Summary:         Test class for SoftValidationLogicExpression
// Created On:      08/05/2021

// Modification Log: (Name - Change Summary - Initial)
====================
Konstantin Ermolenko - 08/05/2021 - created class
*******************************************************************************/

@IsTest
private class SoftValidationLogicExpressionTest{

    @IsTest
    static void testSoftValidationLogicExpression(){
        SoftValidationLogicExpression logicExp;

        //test invalid scenario 1
        Boolean exceptionOccurred = false;

        try{
            logicExp = new SoftValidationLogicExpression('AND 1');
        }
        catch(Exception ex){
            exceptionOccurred = true;
        }

        System.assertEquals(true, exceptionOccurred);

        //test invalid scenario 2
        exceptionOccurred = false;

        try{
            logicExp = new SoftValidationLogicExpression('AND OR 2');
        }
        catch(Exception ex){
            exceptionOccurred = true;
        }

        System.assertEquals(true, exceptionOccurred);

        //test invalid scenario 3
        exceptionOccurred = false;

        try{
            logicExp = new SoftValidationLogicExpression('1 NOT 2');
        }
        catch(Exception ex){
            exceptionOccurred = true;
        }

        System.assertEquals(true, exceptionOccurred);

        //test invalid scenario 4
        exceptionOccurred = false;

        try{
            logicExp = new SoftValidationLogicExpression('1 2');
        }
        catch(Exception ex){
            exceptionOccurred = true;
        }

        System.assertEquals(true, exceptionOccurred);

        //test invalid scenario 5
        exceptionOccurred = false;

        try{
            logicExp = new SoftValidationLogicExpression('10 AND');
        }
        catch(Exception ex){
            exceptionOccurred = true;
        }

        System.assertEquals(true, exceptionOccurred);

        //test invalid scenario 6
        exceptionOccurred = false;

        try{
            logicExp = new SoftValidationLogicExpression('1 OR AND');
        }
        catch(Exception ex){
            exceptionOccurred = true;
        }

        System.assertEquals(true, exceptionOccurred);

        //test valid scenario 1
        logicExp = new SoftValidationLogicExpression('(1 AND 2) OR NOT 3');
        exceptionOccurred = false;

        try{
            logicExp.evaluate(new List<Boolean>{true, true}, new Map<String, Object>{'allowInvalidIndices' => true});
        }
        catch(Exception ex){
            exceptionOccurred = true;
        }

        System.assertEquals(false, exceptionOccurred);

        //test valid scenario 2
        Boolean result = logicExp.evaluate(new List<Boolean>{true, null, true}, new Map<String, Object>{'allowNulls' => true});
        System.assertEquals(false, result);

        //misc
        logicExp.getParsingResultsJSON();
        logicExp.getEvaluationLog();
    }
}