/******************************************************************************
// File Name:       SoftValidationFormulaExpressionTest
// Summary:         Test class for SoftValidationFormulaExpression
// Created On:      08/06/2021

// Modification Log: (Name - Change Summary - Initial)
====================
Konstantin Ermolenko - 08/06/2021 - created class
Konstantin Ermolenko - 11/04/2021 - added coverage for the new logical operators and functions
*******************************************************************************/

@IsTest
private class SoftValidationFormulaExpressionTest{

    @IsTest
    static void testGenericFormulaExpressionFunctionality(){
        //test converting Integer to Decimal
        SoftValidationFormulaExpression exp = new SoftValidationFormulaExpression('1', 'STATIC');
        SoftValidationFormulaExpression.ExpressionEvaluationResult result = exp.evaluate(null, 'DECIMAL', null, null);
        System.assertEquals(1.0, result.value);

        //test "type mismatch"
        Boolean exceptionOccurred = false;
        exp = new SoftValidationFormulaExpression('1', 'STATIC');

        try{
            result = exp.evaluate(null, 'STRING', null, null);
        }
        catch(Exception ex){
            exceptionOccurred = true;
        }

        System.assertEquals(true, exceptionOccurred);

        //test invalid expression
        exceptionOccurred = false;

        try{
            exp = new SoftValidationFormulaExpression('#test', null);
        }
        catch(Exception ex){
            exceptionOccurred = true;
        }

        System.assertEquals(true, exceptionOccurred);

        //test invalid expression (type mismatch)
        exp = new SoftValidationFormulaExpression('false + 2', null);
        exceptionOccurred = false;

        try{
            result = exp.evaluate(null, null, null, null);
        }
        catch(Exception ex){
            exceptionOccurred = true;
        }

        System.assertEquals(true, exceptionOccurred);

        //test invalid expression (invalid field expression)
        exceptionOccurred = false;

        try{
            exp = new SoftValidationFormulaExpression('Account__c.Name', null);
        }
        catch(Exception ex){
            exceptionOccurred = true;
        }

        System.assertEquals(true, exceptionOccurred);

        //test formula expression type
        exp = new SoftValidationFormulaExpression('false', null);
        System.assertEquals('STATIC', exp.expressionType);

        //test formula with fields
        Opportunity opp = new Opportunity();
        opp.putSObject('Account', new Account(Name = 'Test'));

        exp = new SoftValidationFormulaExpression('(Account.Name & "-test") & "1"', 'FORMULA');
        Map<String, Map<String, SoftValidationUtils.SoftValidationFieldValue>> fieldValueCache = new Map<String, Map<String, SoftValidationUtils.SoftValidationFieldValue>>();
        result = exp.evaluate(opp, null, fieldValueCache, null);
        System.assertEquals('Test-test1', result.value);

        exp.getFieldsForQuery(new Map<String, Set<String>>());
        exp.getParsingResultsJSON();
        exp.getEvaluationLog();

        //test operators (Integer)
        exp = new SoftValidationFormulaExpression('1 + 1', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(2, result.value);

        exp = new SoftValidationFormulaExpression('1 - 1', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(0, result.value);

        exp = new SoftValidationFormulaExpression('1 * 1', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(1, result.value);

        exp = new SoftValidationFormulaExpression('1 / 1', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(1, result.value);

        exp = new SoftValidationFormulaExpression('1 / 2', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(0.5, result.value);

        exp = new SoftValidationFormulaExpression('1 / null', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(null, result.value);

        exp = new SoftValidationFormulaExpression('null + null', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(null, result.value);

        //test operators (Decimal)
        exp = new SoftValidationFormulaExpression('1.5 + 1.5', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(3, result.value);

        exp = new SoftValidationFormulaExpression('1.5 - 1.5', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(0, result.value);

        exp = new SoftValidationFormulaExpression('1.5 * 1.5', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(2.25, result.value);

        exp = new SoftValidationFormulaExpression('1.5 / 1.5', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(1, result.value);

        exp = new SoftValidationFormulaExpression('1.5 / null', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(null, result.value);

        //test operators (Date)
        exp = new SoftValidationFormulaExpression('TODAY() + 1', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(Date.today().addDays(1), result.value);

        //test invalid operator with Date
        exp = new SoftValidationFormulaExpression('TODAY() * 1', 'FORMULA');
        exceptionOccurred = false;

        try{
            result = exp.evaluate(null, null, null, null);
        }
        catch(Exception ex){
            exceptionOccurred = true;
        }

        System.assertEquals(true, exceptionOccurred);

        //test invalid order of expressions with Date
        exp = new SoftValidationFormulaExpression('1 + TODAY()', 'FORMULA');
        exceptionOccurred = false;

        try{
            result = exp.evaluate(null, null, null, null);
        }
        catch(Exception ex){
            exceptionOccurred = true;
        }

        System.assertEquals(true, exceptionOccurred);

        //test operators (Datetime)
        exp = new SoftValidationFormulaExpression('NOW() + 1', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(Datetime.now().addDays(1), result.value);

        //test invalid operator with Datetime
        exp = new SoftValidationFormulaExpression('NOW() * 1', 'FORMULA');
        exceptionOccurred = false;

        try{
            result = exp.evaluate(null, null, null, null);
        }
        catch(Exception ex){
            exceptionOccurred = true;
        }

        System.assertEquals(true, exceptionOccurred);

        //test invalid order of expressions with Datetime
        exp = new SoftValidationFormulaExpression('1 + NOW()', 'FORMULA');
        exceptionOccurred = false;

        try{
            result = exp.evaluate(null, null, null, null);
        }
        catch(Exception ex){
            exceptionOccurred = true;
        }

        System.assertEquals(true, exceptionOccurred);

        //test "&" with invalid types
        exp = new SoftValidationFormulaExpression('1 & "123"', 'FORMULA');
        exceptionOccurred = false;

        try{
            result = exp.evaluate(null, null, null, null);
        }
        catch(Exception ex){
            exceptionOccurred = true;
        }

        System.assertEquals(true, exceptionOccurred);

        //test order of operators
        exp = new SoftValidationFormulaExpression('2 + 2 * 2', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(6, result.value);

        //test sub-expression
        exp = new SoftValidationFormulaExpression('-(2 + 2) * 2', 'FORMULA');
        result = exp.evaluate(-8, null, null, null);
        exp.getFieldsForQuery(new Map<String, Set<String>>());
        exp.getParsingResultsJSON();

        //test static expression
        exp = new SoftValidationFormulaExpression('test', 'STATIC');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals('test', result.value);

        //test with invalid data-source
        exp = new SoftValidationFormulaExpression('Name', 'FIELD');
        exceptionOccurred = false;

        try{
            result = exp.evaluate(exp, null, null, null);
        }
        catch(Exception ex){
            exceptionOccurred = true;
        }

        System.assertEquals(true, exceptionOccurred);

        //test dates subtraction
        exp = new SoftValidationFormulaExpression('TODAY() - TODAY()', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(0, result.value);

        exp = new SoftValidationFormulaExpression('NOW() - TODAY()', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assert((Decimal) result.value >= 0);

        //utility methods
        SoftValidationFormulaExpression.getSupportedExpressionTypes();
        SoftValidationFormulaExpression.getSupportedDataTypes();

        //custom data-source
        SoftValidationFormulaExpression.DataSourceObjectGeneric customObject = new SoftValidationFormulaExpression.DataSourceObjectGeneric(new Map<String, SoftValidationFormulaExpression.DataSourceObjectGetValueResult>{
            'Name1' => new SoftValidationFormulaExpression.DataSourceObjectGetValueResult('test', 'STRING'),
            'Name2' => null
        });

        exp = new SoftValidationFormulaExpression('Name1 & Name2', 'FORMULA');
        exp.getFieldsForQuery(new Map<String, Set<String>>());
        result = exp.evaluate(customObject, null, null, null);
        System.assertEquals('test', result.value);

        SoftValidationFormulaExpression.DataSourceObjectGetValueResult testDataSourceObjectGetValueResult = new SoftValidationFormulaExpression.DataSourceObjectGetValueResult(null, null);

        //test misc Function methods
        exp = new SoftValidationFormulaExpression('YEAR(Account.CreatedDate)', 'FORMULA');
        exp.getFieldsForQuery(new Map<String, Set<String>>());
        exp.getParsingResultsJSON();

        //test Functions with invalid number of input params
        exceptionOccurred = false;

        try{
            exp = new SoftValidationFormulaExpression('LEFT("test", 2, 10)', 'FORMULA');
        }
        catch(Exception ex){
            exceptionOccurred = true;
        }

        System.assertEquals(true, exceptionOccurred);

        //test Functions with invalid input params type
        exp = new SoftValidationFormulaExpression('LEFT("test", "test")', 'FORMULA');
        exceptionOccurred = false;

        try{
            result = exp.evaluate(null, null, null, null);
        }
        catch(Exception ex){
            exceptionOccurred = true;
        }

        System.assertEquals(true, exceptionOccurred);
    }

    @IsTest
    static void testFormulaExpressionLogicalOperators(){
        //equality operators
        SoftValidationFormulaExpression exp = new SoftValidationFormulaExpression('1 = null', 'FORMULA');
        SoftValidationFormulaExpression.ExpressionEvaluationResult result = exp.evaluate(null, null, null, null);
        System.assertEquals(false, result.value);

        exp = new SoftValidationFormulaExpression('1 != null', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(true, result.value);

        exp = new SoftValidationFormulaExpression('1 + 2.5 = 3.5', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(true, result.value);

        exp = new SoftValidationFormulaExpression('1 != 2', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(true, result.value);

        //test "type mismatch"
        Boolean exceptionOccurred = false;
        exp = new SoftValidationFormulaExpression('1 == "test"', 'FORMULA');

        try{
            result = exp.evaluate(null, null, null, null);
        }
        catch(Exception ex){
            exceptionOccurred = true;
        }

        System.assertEquals(true, exceptionOccurred);

        //inequality operators
        exp = new SoftValidationFormulaExpression('1 > 2', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(false, result.value);

        exp = new SoftValidationFormulaExpression('1 >= 2', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(false, result.value);

        exp = new SoftValidationFormulaExpression('1 < 2.5', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(true, result.value);

        exp = new SoftValidationFormulaExpression('1 <= 2.5', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(true, result.value);

        exp = new SoftValidationFormulaExpression('TODAY() > TODAY()', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(false, result.value);

        exp = new SoftValidationFormulaExpression('TODAY() >= TODAY()', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(true, result.value);

        exp = new SoftValidationFormulaExpression('TODAY() < NOW()', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(true, result.value);

        exp = new SoftValidationFormulaExpression('NOW() <= TODAY() + 1', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(true, result.value);

        //logical operators
        exp = new SoftValidationFormulaExpression('true && false', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(false, result.value);

        exp = new SoftValidationFormulaExpression('true || false', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(true, result.value);
    }

    @IsTest
    static void testFormulaExpressionMathFunctions(){
        //VALUE
        SoftValidationFormulaExpression exp = new SoftValidationFormulaExpression('VALUE(null)', 'FORMULA');
        SoftValidationFormulaExpression.ExpressionEvaluationResult result = exp.evaluate(null, null, null, null);
        System.assertEquals(null, result.value);

        exp = new SoftValidationFormulaExpression('VALUE("1")', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(1, result.value);

        exp = new SoftValidationFormulaExpression('VALUE("1.5")', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(1.5, result.value);

        exp = new SoftValidationFormulaExpression('VALUE("test")', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(null, result.value);

        //ROUND
        exp = new SoftValidationFormulaExpression('ROUND(null, null)', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(null, result.value);

        exp = new SoftValidationFormulaExpression('ROUND(2, 0)', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(2, result.value);

        exp = new SoftValidationFormulaExpression('ROUND(2.2, 0)', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(2, result.value);

        exp = new SoftValidationFormulaExpression('ROUND(1.123, 2)', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(1.12, result.value);

        //TRUNC
        exp = new SoftValidationFormulaExpression('TRUNC(null)', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(null, result.value);

        exp = new SoftValidationFormulaExpression('TRUNC(1)', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(1, result.value);

        exp = new SoftValidationFormulaExpression('TRUNC(1.5)', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(1, result.value);
    }

    @IsTest
    static void testFormulaExpressionDatetimeFunctions(){
        //TODAY
        SoftValidationFormulaExpression exp = new SoftValidationFormulaExpression('TODAY()', 'FORMULA');
        SoftValidationFormulaExpression.ExpressionEvaluationResult result = exp.evaluate(null, null, null, null);
        System.assertEquals(Date.today(), result.value);

        //NOW
        exp = new SoftValidationFormulaExpression('NOW()', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(Datetime.now(), result.value);

        //DATE
        exp = new SoftValidationFormulaExpression('DATE(2021, 8, 6)', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(Date.newInstance(2021, 8, 6), result.value);

        //DATEVALUE
        exp = new SoftValidationFormulaExpression('DATEVALUE(TODAY())', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(Date.today(), result.value);

        exp = new SoftValidationFormulaExpression('DATEVALUE(NOW())', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(Date.today(), result.value);

        exp = new SoftValidationFormulaExpression('DATEVALUE("2021-08-06")', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assert(result.value != null && result.value instanceof Date);

        exp = new SoftValidationFormulaExpression('DATEVALUE("test")', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(null, result.value);

        //DATETIMEVALUE
        exp = new SoftValidationFormulaExpression('DATETIMEVALUE(NOW())', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(Datetime.now(), result.value);

        exp = new SoftValidationFormulaExpression('DATETIMEVALUE(TODAY())', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(Datetime.newInstance(Date.today(), Time.newInstance(0, 0, 0, 0)), result.value);

        exp = new SoftValidationFormulaExpression('DATETIMEVALUE("2021-08-06 12:00:00")', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assert(result.value != null && result.value instanceof Datetime);

        exp = new SoftValidationFormulaExpression('DATETIMEVALUE("test")', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(null, result.value);

        //SIMPLE FUCNTIONS
        exp = new SoftValidationFormulaExpression('YEAR(null)', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(null, result.value);

        exp = new SoftValidationFormulaExpression('YEAR(NOW())', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(Datetime.now().year(), result.value);

        exp = new SoftValidationFormulaExpression('MONTH(NOW())', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(Datetime.now().month(), result.value);

        exp = new SoftValidationFormulaExpression('DAY(NOW())', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(Datetime.now().day(), result.value);

        exp = new SoftValidationFormulaExpression('HOUR(NOW())', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(Datetime.now().hour(), result.value);

        exp = new SoftValidationFormulaExpression('MINUTE(NOW())', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(Datetime.now().minute(), result.value);

        exp = new SoftValidationFormulaExpression('SECOND(NOW())', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(Datetime.now().second(), result.value);

        exp = new SoftValidationFormulaExpression('WEEKDAY(NOW())', 'FORMULA');
        result = exp.evaluate(null, null, null, null);

        exp = new SoftValidationFormulaExpression('YEAR(TODAY())', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(Datetime.now().year(), result.value);

        exp = new SoftValidationFormulaExpression('MONTH(TODAY())', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(Datetime.now().month(), result.value);

        exp = new SoftValidationFormulaExpression('DAY(TODAY())', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(Datetime.now().day(), result.value);

        exp = new SoftValidationFormulaExpression('WEEKDAY(TODAY())', 'FORMULA');
        result = exp.evaluate(null, null, null, null);

        exp = new SoftValidationFormulaExpression('HOUR(TODAY())', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(0, result.value);

        //ADDMONTHS
        exp = new SoftValidationFormulaExpression('ADDMONTHS(null, null)', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(null, result.value);

        exp = new SoftValidationFormulaExpression('ADDMONTHS(NOW(), 1)', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(Datetime.now().addMonths(1), result.value);

        exp = new SoftValidationFormulaExpression('ADDMONTHS(TODAY(), 1)', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(Date.today().addMonths(1), result.value);
    }

    @IsTest
    static void testFormulaExpressionTextFunctions(){
        //TEXT
        SoftValidationFormulaExpression exp = new SoftValidationFormulaExpression('TEXT(1)', 'FORMULA');
        SoftValidationFormulaExpression.ExpressionEvaluationResult result = exp.evaluate(null, null, null, null);
        System.assertEquals('1', result.value);

        //LOWER
        exp = new SoftValidationFormulaExpression('LOWER(null)', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(null, result.value);

        exp = new SoftValidationFormulaExpression('LOWER("TEST")', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals('test', result.value);

        //UPPER
        exp = new SoftValidationFormulaExpression('UPPER("test")', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals('TEST', result.value);

        //TRIM
        exp = new SoftValidationFormulaExpression('TRIM(" test ")', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals('test', result.value);

        //LEN
        exp = new SoftValidationFormulaExpression('LEN("test")', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(4, result.value);

        //LEFT
        exp = new SoftValidationFormulaExpression('LEFT("test", 2)', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals('te', result.value);

        //RIGHT
        exp = new SoftValidationFormulaExpression('RIGHT("test", 2)', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals('st', result.value);

        //MID
        exp = new SoftValidationFormulaExpression('MID("test", 0, 2)', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals('te', result.value);

        exp = new SoftValidationFormulaExpression('MID("", 10, 15)', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(null, result.value);
    }

    @IsTest
    static void testFormulaExpressionLogicFunctions(){
        //BLANKVALUE
        SoftValidationFormulaExpression exp = new SoftValidationFormulaExpression('BLANKVALUE(NULL, "test")', 'FORMULA');
        SoftValidationFormulaExpression.ExpressionEvaluationResult result = exp.evaluate(null, null, null, null);
        System.assertEquals('test', result.value);

        exp = new SoftValidationFormulaExpression('BLANKVALUE(" ", "test")', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals('test', result.value);

        //ISBLANK
        exp = new SoftValidationFormulaExpression('ISBLANK(null)', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(true, result.value);

        exp = new SoftValidationFormulaExpression('ISBLANK("")', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(true, result.value);

        exp = new SoftValidationFormulaExpression('ISBLANK(1)', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(false, result.value);

        //AND
        exp = new SoftValidationFormulaExpression('AND(true, false)', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(false, result.value);

        //OR
        exp = new SoftValidationFormulaExpression('OR(true, false)', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(true, result.value);

        //NOT
        exp = new SoftValidationFormulaExpression('NOT(false)', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(true, result.value);

        //CASE
        exp = new SoftValidationFormulaExpression('CASE(NULL, 1, "test1", 2, "test2", "else")', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals('else', result.value);

        exp = new SoftValidationFormulaExpression('CASE(1, 1.5, "test1.5", 2, "test2", 1, "test1", "else")', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals('test1', result.value);

        //IF
        exp = new SoftValidationFormulaExpression('IF(true, 1, 2)', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(1, result.value);

        exp = new SoftValidationFormulaExpression('IF(false, 1, 2)', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(2, result.value);

        //ISNUMBER
        exp = new SoftValidationFormulaExpression('ISNUMBER("test")', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(false, result.value);

        exp = new SoftValidationFormulaExpression('ISNUMBER("123")', 'FORMULA');
        result = exp.evaluate(null, null, null, null);
        System.assertEquals(true, result.value);
    }
}