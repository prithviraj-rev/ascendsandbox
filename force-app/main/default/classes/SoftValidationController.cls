/******************************************************************************
// File Name:       SoftValidationController
// Summary:         Controller class for "softValidation" LWC
// Test Class:      SoftValidationControllerTest
// Created On:      07/30/2021

// Modification Log: (Name - Change Summary - Initial)
====================
Konstantin Ermolenko - 07/30/2021 - created class
Konstantin Ermolenko - 10/28/2021 - added support for Merge Fields in Rule Message
Konstantin Ermolenko - 11/03/2021 - added "MessageCustomSettings__c" to the Rule query
*******************************************************************************/

public without sharing class SoftValidationController {
    public static final Integer MAX_CRITERIA_NUMBER = 10;

    private static final Set<Type> CUSTOM_EXCEPTION_TYPES = new Set<Type>{
        SoftValidationControllerException.class,
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
    public static AuraHelper.Response getRulesQualifiedForEvaluation(Map<String, Object> params){
        AuraHelper.Response response;

        try{
            Boolean showComponent = true; //(UserInfo.getUserId() == '0050L000009mlGcQAI');
            Map<String, Object> responseData = new Map<String, Object>{
                'showComponent' => showComponent
            };

            if (showComponent){
                Id recordId = (Id) params.get('recordId');

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
                if (records.isEmpty()) throw new SoftValidationControllerException('Cannot find record for Id = ' + recordId + ' in the database. Was it deleted?');
                SObject record = records.get(0);

                if (recordHasRTField){
                    SObject rtRecord = record.getSObject('RecordType');
                    if (rtRecord != null) recordRTDevName = (String) rtRecord.get('DeveloperName');
                }

                User u = [SELECT Business_Unit__c FROM User WHERE Id = :UserInfo.getUserId()];
                userBusinessUnit = u.Business_Unit__c;

                String rulesQuery = 'SELECT Name, MessageType__c, Message__c FROM SoftValidationRule__c WHERE ObjectAPIName__c = :sObjectName AND IsActive__c = TRUE';
                if (String.isNotBlank(recordRTDevName)) rulesQuery += ' AND (RecordTypeDevName__c = :recordRTDevName OR RecordTypeDevName__c = NULL)';
                if (String.isNotBlank(userBusinessUnit)) rulesQuery += ' AND (BusinessUnit__c = :userBusinessUnit OR BusinessUnit__c = NULL)';
                if (String.isBlank(userBusinessUnit)) rulesQuery += ' AND BusinessUnit__c = NULL';
                rulesQuery += ' ORDER BY SequenceNumber__c DESC NULLS LAST, CreatedDate';

                List<SoftValidationRule__c> qualifiedRuleRecords = (List<SoftValidationRule__c>) Database.query(rulesQuery);
                List<Map<String, Object>> qualifiedRules = new List<Map<String, Object>>();

                for (SoftValidationRule__c rule : qualifiedRuleRecords){
                    if (String.isNotBlank(rule.MessageType__c) && String.isNotBlank(rule.Message__c)){
                        Map<String, Object> qualifiedRule = new Map<String, Object>();

                        qualifiedRule.put('id', rule.Id);
                        qualifiedRule.put('name', rule.Name);

                        qualifiedRules.add(qualifiedRule);
                    }
                }

                responseData.put('sObjectName', sObjectName);
                responseData.put('rules', qualifiedRules);
            }

            response = new AuraHelper.Response(responseData);
        }
        catch(Exception ex){
            response = new AuraHelper.Response(ex);
        }

        return response;
    }

    //only qualified rules or rules with an exception are returned in the response.
    @AuraEnabled(Cacheable=false)
    public static AuraHelper.Response evaluateRules(Map<String, Object> params){
        AuraHelper.Response response;

        try{
            Map<String, Object> responseData = new Map<String, Object>{};

            Id recordId = (Id) params.get('recordId');
            String sObjectName = (String) params.get('sObjectName');
            String rulesJSON = (String) params.get('rulesJSON'); //sending as List<Map<String, Object>> right away does not work
            Integer batchIndex = Integer.valueOf(params.get('batchIndex'));

            List<Object> rules = (List<Object>) JSON.deserializeUntyped(rulesJSON);
            Map<Id, SoftValidationRule__c> ruleRecords = queryRules(rules);
            Map<Id, SoftValidationRule> softValidationRules = new Map<Id, SoftValidationRule>();

            for (SoftValidationRule__c ruleRecord : ruleRecords.values()){
                try{
                    SoftValidationRule softValidationRule = initSoftValidationRule(ruleRecord);
                    softValidationRules.put(ruleRecord.Id, softValidationRule);
                }
                catch(Exception ex){
                    registerResponseErrorRule(responseData, ruleRecord.Id, ex);
                }
            }

            if (!softValidationRules.isEmpty()){
                SObject dataSourceRecord = getDataSourceRecord(sObjectName, recordId, softValidationRules);
                Map<String, Map<String, SoftValidationUtils.SoftValidationFieldValue>> fieldValueCache = new Map<String, Map<String, SoftValidationUtils.SoftValidationFieldValue>>();
                List<SoftValidationRule__c> qualifiedSoftValidationRules = new List<SoftValidationRule__c>();

                for (Id ruleRecordId : softValidationRules.keySet()){
                    SoftValidationRule softValidationRule = softValidationRules.get(ruleRecordId);
                    SoftValidationRule__c ruleRecord = ruleRecords.get(ruleRecordId);

                    try{
                        Boolean isQualified = softValidationRule.evaluate(dataSourceRecord, fieldValueCache, null);
                        if (isQualified) qualifiedSoftValidationRules.add(ruleRecord);
                    }
                    catch(Exception ex){
                        registerResponseErrorRule(responseData, ruleRecordId, ex);
                    }
                }

                if (!qualifiedSoftValidationRules.isEmpty()){
                    Map<Id, SoftValidationMergeFieldsProcessor> mergeFieldsProcessors = new Map<Id, SoftValidationMergeFieldsProcessor>();

                    for (SoftValidationRule__c ruleRecord : qualifiedSoftValidationRules){
                        try{
                            SoftValidationMergeFieldsProcessor mergeFieldsProcessor = new SoftValidationMergeFieldsProcessor(ruleRecord.Message__c, true);
                            mergeFieldsProcessors.put(ruleRecord.Id, mergeFieldsProcessor);
                        }
                        catch(Exception ex){
                            registerResponseErrorRule(responseData, ruleRecord.Id, ex);
                        }
                    }

                    if (!mergeFieldsProcessors.isEmpty()){
                        dataSourceRecord = getDataSourceRecord(sObjectName, recordId, mergeFieldsProcessors);
                        fieldValueCache = new Map<String, Map<String, SoftValidationUtils.SoftValidationFieldValue>>();

                        for (Id ruleRecordId : mergeFieldsProcessors.keySet()){
                            SoftValidationMergeFieldsProcessor mergeFieldsProcessor = mergeFieldsProcessors.get(ruleRecordId);
                            SoftValidationRule__c ruleRecord = ruleRecords.get(ruleRecordId);

                            try{
                                String ruleMessage = mergeFieldsProcessor.evaluate(dataSourceRecord, fieldValueCache, null);

                                Map<String, Object> responseRule = new Map<String, Object>();
                                responseRule.put('id', ruleRecordId);
                                responseRule.put('success', true);
                                responseRule.put('type', ruleRecord.MessageType__c);
                                responseRule.put('bodyHeight', ruleRecord.MessageMaxHeight__c);
                                responseRule.put('msg', ruleMessage);
                                responseRule.put('customSettings', ruleRecord.MessageCustomSettings__c);

                                responseData.put(ruleRecordId, responseRule);
                            }
                            catch(Exception ex){
                                registerResponseErrorRule(responseData, ruleRecordId, ex);
                            }
                        }
                    }
                }
            }

            response = new AuraHelper.Response(responseData);
        }
        catch(Exception ex){
            response = new AuraHelper.Response(ex);
        }

        return response;
    }

    public static Map<Id, SoftValidationRule__c> queryRules(List<Object> rules){
        Set<Id> ruleIds = new Set<Id>();

        for (Integer i = 0; i < rules.size(); i++){
            Map<String, Object> rule = (Map<String, Object>) rules.get(i);

            Id ruleId = (Id) rule.get('id');
            ruleIds.add(ruleId);
        }

        String queryFields = 'Message__c, MessageType__c, MessageMaxHeight__c, MessageCustomSettings__c, FilterLogic__c, ObjectAPIName__c, IsActive__c, RecordTypeDevName__c, BusinessUnit__c';

        for (Integer i = 1; i <= MAX_CRITERIA_NUMBER; i++){
            queryFields += ', Criteria' + i + 'LeftExpressionType__c' +
                           ', Criteria' + i + 'LeftExpression__c' +
                           ', Criteria' + i + 'Operator__c' +
                           ', Criteria' + i + 'RightExpressionType__c' +
                           ', Criteria' + i + 'RightExpression__c';
        }

        String query = 'SELECT ' + queryFields + ' FROM SoftValidationRule__c WHERE Id IN :ruleIds';
        List<SoftValidationRule__c> ruleRecords = (List<SoftValidationRule__c>) Database.query(query);

        return new Map<Id, SoftValidationRule__c>(ruleRecords);
    }

    public static SoftValidationRule initSoftValidationRule(SoftValidationRule__c ruleRecord){
        SoftValidationRule rule = new SoftValidationRule(ruleRecord.FilterLogic__c);

        for (Integer i = 1; i <= MAX_CRITERIA_NUMBER; i++){
            String leftExpressionType = (String) ruleRecord.get('Criteria' + i + 'LeftExpressionType__c');
            String leftExpression = (String) ruleRecord.get('Criteria' + i + 'LeftExpression__c');
            String operator = (String) ruleRecord.get('Criteria' + i + 'Operator__c');
            String rightExpressionType = (String) ruleRecord.get('Criteria' + i + 'RightExpressionType__c');
            String rightExpression = (String) ruleRecord.get('Criteria' + i + 'RightExpression__c');

            if (String.isBlank(leftExpression)) break;

            rule.addCriterion(leftExpressionType, leftExpression, operator, rightExpressionType, rightExpression);
        }

        return rule;
    }

    public static SObject getDataSourceRecord(String sObjectName, Id recordId, Map<Id, SoftValidationRule> softValidationRules){
        Map<String, Set<String>> fieldsForQuery = new Map<String, Set<String>>();

        for (SoftValidationRule softValidationRule : softValidationRules.values()){
            softValidationRule.getFieldsForQuery(fieldsForQuery);
        }

        return getDataSourceRecord(sObjectName, recordId, fieldsForQuery);
    }

    public static SObject getDataSourceRecord(String sObjectName, Id recordId, Map<Id, SoftValidationMergeFieldsProcessor> mergeFieldsProcessors){
        Map<String, Set<String>> fieldsForQuery = new Map<String, Set<String>>();

        for (SoftValidationMergeFieldsProcessor mergeFieldsProcessor : mergeFieldsProcessors.values()){
            mergeFieldsProcessor.getFieldsForQuery(fieldsForQuery);
        }

        return getDataSourceRecord(sObjectName, recordId, fieldsForQuery);
    }

    public static SObject getDataSourceRecord(String sObjectName, Id recordId, Map<String, Set<String>> fieldsForQuery){
        SObject dataSourceRecord;

        Set<String> primaryObjectFieldsSet = fieldsForQuery.get('PRIMARY');

        if (primaryObjectFieldsSet != null && !primaryObjectFieldsSet.isEmpty()){
            String primaryObjectFields = String.escapeSingleQuotes(String.join(new List<String>(primaryObjectFieldsSet), ','));
            String query = 'SELECT ' + primaryObjectFields + ' FROM ' + sObjectName + ' WHERE Id = :recordId';

            List<SObject> records = Database.query(query);
            if (records.isEmpty()) throw new SoftValidationControllerException('Cannot find record for Id = ' + recordId + ' in the database. Was it deleted?');
            dataSourceRecord = records.get(0);
        }

        return dataSourceRecord;
    }

    public static void registerResponseErrorRule(Map<String, Object> responseData, Id ruleId, Exception ex){
        Boolean isCustomException = CUSTOM_EXCEPTION_TYPES.contains(Type.forName(ex.getTypeName()));

        Map<String, Object> responseErrorRule = new Map<String, Object>{
            'id' => ruleId,
            'success' => false,
            'errorMessage' => ex.getMessage()
        };

        if (!isCustomException) responseErrorRule.put('errorDetails', ex.getStackTraceString());

        responseData.put(ruleId, responseErrorRule);
    }

    public class SoftValidationControllerException extends Exception {}
}