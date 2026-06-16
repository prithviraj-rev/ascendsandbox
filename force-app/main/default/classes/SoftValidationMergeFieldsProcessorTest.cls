/******************************************************************************
// File Name:       SoftValidationMergeFieldsProcessorTest
// Summary:         Test class for SoftValidationMergeFieldsProcessor
// Created On:      10/27/2021

// Modification Log: (Name - Change Summary - Initial)
====================
Konstantin Ermolenko - 10/27/2021 - created class
*******************************************************************************/

@IsTest
private class SoftValidationMergeFieldsProcessorTest {

    @IsTest
    static void testSoftValidationMergeFieldsProcessor(){
        //test init with invalid Logic Filter
        SoftValidationMergeFieldsProcessor mergeFieldsProcessor;

        //missing closing bracket
        Boolean exceptionOccurred = false;

        try{
            mergeFieldsProcessor = new SoftValidationMergeFieldsProcessor('test {!123', false);
        }
        catch(Exception ex){
            exceptionOccurred = true;
        }

        System.assertEquals(true, exceptionOccurred);

        //invalid expression
        exceptionOccurred = false;

        try{
            mergeFieldsProcessor = new SoftValidationMergeFieldsProcessor('test {!testFn(123)}', false);
        }
        catch(Exception ex){
            exceptionOccurred = true;
        }

        System.assertEquals(true, exceptionOccurred);

        //test evaluate with valid params, without merge fields:
        mergeFieldsProcessor = new SoftValidationMergeFieldsProcessor('test', false);
        String evalResult = mergeFieldsProcessor.evaluate(null, null, null);
        System.assertEquals('test', evalResult);

        //test evaluate with valid params, with merge fields:
        mergeFieldsProcessor = new SoftValidationMergeFieldsProcessor('2 + 2 = {!2 + 2}', false);
        evalResult = mergeFieldsProcessor.evaluate(null, null, null);
        System.assertEquals('2 + 2 = 4', evalResult);

        //test evaluation error:
        exceptionOccurred = false;

        mergeFieldsProcessor = new SoftValidationMergeFieldsProcessor('{!Owner.Name}', false);

        try{
            //not sending data-source record for '{!Owner.Name}' merge field
            evalResult = mergeFieldsProcessor.evaluate(null, null, new Map<String, Object>{'mergeFieldEvaluateOnError' => 'throwException'});
        }
        catch(Exception ex){
            exceptionOccurred = true;
        }

        System.assertEquals(true, exceptionOccurred);

        //misc
        mergeFieldsProcessor.getFieldsForQuery(new Map<String, Set<String>>());
        mergeFieldsProcessor.getExpressions();
        mergeFieldsProcessor.getExpressionsEvaluationResults();
        mergeFieldsProcessor.hasMergeFields();
    }
}