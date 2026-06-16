/******************************************************************************
// File Name:       SoftValidationDebuggerController
// Summary:         Controller class for "softValidationDebugger" LWC
// Test Class:      SoftValidationDebuggerControllerTest
// Created On:      08/02/2021

// Modification Log: (Name - Change Summary - Initial)
====================
Konstantin Ermolenko - 08/02/2021 - created class
Konstantin Ermolenko - 10/28/2021 - added support for Merge Fields in Rule Message
*******************************************************************************/

public without sharing class SoftValidationDebuggerController {
    private static final Set<Type> CUSTOM_EXCEPTION_TYPES = new Set<Type>{
        SoftValidationDebuggerControllerException.class,
        SoftValidationLogicExpression.SoftValidationLogicExpressionParseException.class,
        SoftValidationLogicExpression.SoftValidationLogicExpressionEvaluateException.class,
        SoftValidationFormulaExpression.SoftValidationFormulaExpressionParseException.class,
        SoftValidationFormulaExpression.SoftValidationFormulaExpressionEvaluateException.class,
        SoftValidationCriterion.SoftValidationCriterionParseException.class,
        SoftValidationCriterion.SoftValidationCriterionEvaluateException.class,
        SoftValidationRule.SoftValidationRuleParseException.class,
        SoftValidationRule.SoftValidationRuleEvaluateException.class,
        SoftValidationMergeFieldsProcessor.SoftValidationMergeFieldsProcessorParseException.class,
        SoftValidationMergeFieldsProcessor.SoftValidationMergeFieldsProcessorEvaluateException.class
    };

    @AuraEnabled(Cacheable=false)
    public static AuraHelper.Response evaluateRule(Map<String, Object> params) {
        AuraHelper.Response response;

        try{
            String ruleIdStr = (String) params.get('ruleId');
            String recordIdStr = (String) params.get('recordId');

            if (String.isBlank(ruleIdStr)) throw new SoftValidationDebuggerControllerException('Rule Id is not provided.');
            if (String.isBlank(recordIdStr)) throw new SoftValidationDebuggerControllerException('Record Id is not provided.');

            Id ruleId = (Id) ruleIdStr;
            Id recordId = (Id) recordIdStr;

            String sObjectName;
            Boolean recordHasRTField = false;
            String recordRTDevName;
            String userBusinessUnit;

            Schema.SObjectType sObjectType = recordId.getSobjectType();
            Schema.DescribeSObjectResult sObjectDescribe = sObjectType.getDescribe(SObjectDescribeOptions.DEFERRED);
            sObjectName = sObjectDescribe.getName();
            recordHasRTField = sObjectDescribe.fields.getMap().containsKey('RecordTypeId');

            String recordQuery = 'SELECT Id' + (recordHasRTField ? ', RecordType.DeveloperName' : '') + ' FROM ' + sObjectName + ' WHERE Id = :recordId';
            List<SObject> records = Database.query(recordQuery);
            if (records.isEmpty()) throw new SoftValidationDebuggerControllerException('No "' + sObjectName + '" record was found for Id = "' + recordId + '".');
            SObject record = records.get(0);

            if (recordHasRTField){
                SObject rtRecord = record.getSObject('RecordType');
                if (rtRecord != null) recordRTDevName = (String) rtRecord.get('DeveloperName');
            }

            User u = [SELECT Business_Unit__c FROM User WHERE Id = :UserInfo.getUserId()];
            userBusinessUnit = u.Business_Unit__c;

            String rulesQuery = 'SELECT Id FROM SoftValidationRule__c WHERE ObjectAPIName__c = :sObjectName';
            if (String.isNotBlank(recordRTDevName)) rulesQuery += ' AND (RecordTypeDevName__c = :recordRTDevName OR RecordTypeDevName__c = NULL)';
            if (String.isNotBlank(userBusinessUnit)) rulesQuery += ' AND (BusinessUnit__c = :userBusinessUnit OR BusinessUnit__c = NULL)';
            if (String.isBlank(userBusinessUnit)) rulesQuery += ' AND BusinessUnit__c = NULL';
            rulesQuery += ' AND Id = :ruleId';

            List<SoftValidationRule__c> qualifiedRuleRecords = (List<SoftValidationRule__c>) Database.query(rulesQuery);
            Map<Id, SoftValidationRule__c> ruleRecords = SoftValidationController.queryRules(new List<Object>{new Map<String, Object>{'id' => ruleId}});

            SoftValidationRule__c ruleRecord = ruleRecords.get(ruleId);
            if (ruleRecord == null) throw new SoftValidationDebuggerControllerException('No "Soft Validation Rule" record was found for Id = "' + recordId + '".');

            Boolean isQualifiedForEvaluation = (qualifiedRuleRecords.size() > 0);

            Map<String, Object> responseData = new Map<String, Object>{
                'successParse' => true,
                'successEvaluate' => true,
                'messageSuccessParse' => true,
                'messageSuccessEvaluate' => true,
                'sObjectName' => sObjectName,
                'recordHasRTField' => recordHasRTField,
                'recordRTDevName' => recordRTDevName,
                'userBusinessUnit' => userBusinessUnit,
                'isQualifiedForEvaluation' => isQualifiedForEvaluation,
                'ruleRecord' => ruleRecord,
                'ruleMessage' => null
            };

            if (isQualifiedForEvaluation){
                Map<String, Object> debugData = new Map<String, Object>();
                SoftValidationRule softValidationRule;

                try{
                    softValidationRule = SoftValidationController.initSoftValidationRule(ruleRecord);
                }
                catch(Exception ex){
                    responseData.put('successParse', false);
                    responseData.put('successEvaluate', false);
                    processException(responseData, ex);
                }

                if (softValidationRule != null){
                    Map<String, Object> filterLogicDebugData = new Map<String, Object>();

                    if (softValidationRule.logicExpression != null){
                        filterLogicDebugData.put('parsing', new Map<String, Object>{
                            'resultsJSON' => softValidationRule.logicExpression.getParsingResultsJSON()
                        });
                    }

                    List<Map<String, Object>> criteriaDebugData = new List<Map<String, Object>>();
                    List<SoftValidationCriterion> ruleCriteria = softValidationRule.getCriteria();

                    for (Integer i = 0; i < ruleCriteria.size(); i++){
                        SoftValidationCriterion ruleCriterion = ruleCriteria.get(i);

                        criteriaDebugData.add(new Map<String, Object>{
                            'index' => String.valueOf(i + 1),
                            'parsing' => new Map<String, Object>{
                                'resultsJSON' => ruleCriterion.getParsingResultsJSON()
                            }
                        });
                    }

                    SObject dataSourceRecord = SoftValidationController.getDataSourceRecord(sObjectName, recordId, new Map<Id, SoftValidationRule>{ruleRecord.Id => softValidationRule});
                    Map<String, Map<String, SoftValidationUtils.SoftValidationFieldValue>> fieldValueCache = new Map<String, Map<String, SoftValidationUtils.SoftValidationFieldValue>>();
                    Boolean isQualified = false;

                    try{
                        isQualified = softValidationRule.evaluate(dataSourceRecord, fieldValueCache, null);
                        responseData.put('isQualified', isQualified);
                    }
                    catch(Exception ex){
                        responseData.put('successEvaluate', false);
                        processException(responseData, ex);
                    }

                    if (softValidationRule.logicExpression != null){
                        filterLogicDebugData.put('evaluation', new Map<String, Object>{
                            'result' => softValidationRule.logicExpression.evaluationResult,
                            'logs' => softValidationRule.logicExpression.getEvaluationLog()
                        });
                    }

                    for (Integer i = 0; i < ruleCriteria.size(); i++){
                        SoftValidationCriterion ruleCriterion = ruleCriteria.get(i);

                        Map<String, Object> criterionEvaluationDebugData = new Map<String, Object>{
                            'result' => ruleCriterion.evaluationResult,
                            'operator' => ruleCriterion.operator,
                            'logs' => ruleCriterion.getEvaluationLog().get('own'),
                            'leftExp' => new Map<String, Object>{
                                'result' => ruleCriterion.leftExpression.evaluationResult,
                                'expressionString' => ruleCriterion.leftExpression.expressionString,
                                'logs' => ruleCriterion.leftExpression.getEvaluationLog()
                            },
                            'rightExp' => new Map<String, Object>{
                                'result' => ruleCriterion.rightExpression.evaluationResult,
                                'expressionString' => ruleCriterion.rightExpression.expressionString,
                                'logs' => ruleCriterion.rightExpression.getEvaluationLog()
                            }
                        };

                        Map<String, Object> criterionDebugData = criteriaDebugData.get(i);
                        criterionDebugData.put('evaluation', criterionEvaluationDebugData);
                    }

                    debugData.put('filterLogic', filterLogicDebugData);
                    debugData.put('criteria', criteriaDebugData);

                    if (isQualified){
                        if (String.isBlank(ruleRecord.MessageType__c) || String.isBlank(ruleRecord.Message__c)){
                            responseData.put('messageSuccessParse', false);
                            responseData.put('messageSuccessEvaluate', false);
                            responseData.put('errorMessage', 'Message is not configured on this Rule.');
                        }
                        else{
                            SoftValidationMergeFieldsProcessor mergeFieldsProcessor;

                            try{
                                mergeFieldsProcessor = new SoftValidationMergeFieldsProcessor(ruleRecord.Message__c, true);
                            }
                            catch(Exception ex){
                                responseData.put('messageSuccessParse', false);
                                responseData.put('messageSuccessEvaluate', false);
                                processException(responseData, ex);
                            }

                            if (mergeFieldsProcessor != null){
                                List<Map<String, Object>> mergeFieldsDebugData = new List<Map<String, Object>>();
                                List<SoftValidationFormulaExpression> mergeFieldExpressions = mergeFieldsProcessor.getExpressions();

                                for (Integer i = 0; i < mergeFieldExpressions.size(); i++){
                                    SoftValidationFormulaExpression mergeFieldExpression = mergeFieldExpressions.get(i);

                                    mergeFieldsDebugData.add(new Map<String, Object>{
                                        'index' => String.valueOf(i + 1),
                                        'parsing' => new Map<String, Object>{
                                            'resultsJSON' => mergeFieldExpression.getParsingResultsJSON()
                                        }
                                    });
                                }

                                dataSourceRecord = SoftValidationController.getDataSourceRecord(sObjectName, recordId, new Map<Id, SoftValidationMergeFieldsProcessor>{ruleRecord.Id => mergeFieldsProcessor});
                                fieldValueCache = new Map<String, Map<String, SoftValidationUtils.SoftValidationFieldValue>>();

                                try{
                                    String ruleMessage = mergeFieldsProcessor.evaluate(dataSourceRecord, fieldValueCache, new Map<String, Object>{'mergeFieldEvaluateOnError' => 'ignore'}); //throwException
                                    responseData.put('ruleMessage', ruleMessage);
                                }
                                catch(Exception ex){
                                    responseData.put('messageSuccessEvaluate', false);
                                    processException(responseData, ex);
                                }

                                List<Object> mergeFieldExpressionsEvalResults = mergeFieldsProcessor.getExpressionsEvaluationResults();

                                for (Integer i = 0; i < mergeFieldExpressions.size(); i++){
                                    Map<String, Object> mergeFieldDebugData = mergeFieldsDebugData.get(i);
                                    SoftValidationFormulaExpression expression = mergeFieldExpressions.get(i);
                                    Object evalResult = (i < mergeFieldExpressionsEvalResults.size() ? mergeFieldExpressionsEvalResults.get(i) : null);

                                    Map<String, Object> mergeFieldEvaluationDebugData = new Map<String, Object>{
                                        'result' => evalResult,
                                        'expressionString' => expression.expressionString,
                                        'logs' => expression.getEvaluationLog()
                                    };

                                    mergeFieldDebugData.put('evaluation', mergeFieldEvaluationDebugData);
                                }

                                debugData.put('messageMergeFields', mergeFieldsDebugData);
                            }
                        }
                    }
                }

                responseData.put('debugData', debugData);
            }

            response = new AuraHelper.Response(JSON.serialize(responseData));
        }
        catch(Exception ex){
            response = new AuraHelper.Response(ex);
        }

        return response;
    }

    public static void processException(Map<String, Object> responseData, Exception ex){
        Boolean isCustomException = CUSTOM_EXCEPTION_TYPES.contains(Type.forName(ex.getTypeName()));

        responseData.put('errorMessage', ex.getMessage());
        if (!isCustomException) responseData.put('errorDetails', ex.getStackTraceString());
    }

    public class SoftValidationDebuggerControllerException extends Exception {}
}