/******************************************************************************
// File Name:       SoftValidationMsgEditorController
// Summary:         Controller class for "softValidationMessageEditor" LWC
// Test Class:      SoftValidationMsgEditorControllerTest
// Created On:      11/02/2021

// Modification Log: (Name - Change Summary - Initial)
====================
Konstantin Ermolenko - 11/02/2021 - created class
*******************************************************************************/

public without sharing class SoftValidationMsgEditorController{

    @AuraEnabled(Cacheable=false)
    public static AuraHelper.Response loadRule(Id recordId){
        AuraHelper.Response response;

        try{
            List<SoftValidationRule__c> rules = [
                SELECT
                    MessageType__c, MessageMaxHeight__c, Message__c, MessageCustomSettings__c
                FROM
                    SoftValidationRule__c
                WHERE
                    Id = :recordId
            ];

            response = new AuraHelper.Response(JSON.serialize(rules));
        }
        catch(Exception ex){
            response = new AuraHelper.Response(ex);
        }

        return response;
    }

    @AuraEnabled
    public static AuraHelper.Response saveRule(Map<String, Object> params){
        AuraHelper.Response response;

        try{
            Id ruleId = (Id) params.get('ruleId');
            String messageType = (String) params.get('messageType');
            Decimal messageMaxHeight = (Decimal) params.get('messageMaxHeight');
            String message = (String) params.get('message');
            String backgroundColor = (String) params.get('backgroundColor');
            String iconName = (String) params.get('iconName');
            String iconVariant = (String) params.get('iconVariant');

            SoftValidationRule__c rule = new SoftValidationRule__c(Id = ruleId);
            rule.MessageType__c = messageType;
            rule.MessageMaxHeight__c = messageMaxHeight;
            rule.Message__c = message;
            rule.MessageCustomSettings__c = null;

            if (rule.MessageType__c == 'Custom'){
                Map<String, Object> messageCustomSettings = new Map<String, Object>{
                    'backgroundColor' => backgroundColor,
                    'iconName' => iconName,
                    'iconVariant' => iconVariant
                };

                rule.MessageCustomSettings__c = JSON.serialize(messageCustomSettings);
            }

            SoftValidationRuleHandler.isMessageSave = true;
            List<Database.SaveResult> saveResults = Database.update(new List<SoftValidationRule__c>{rule}, false);

            String saveErrorMsg;
            for (Database.SaveResult sr : saveResults){
                if (sr.isSuccess() == false){
                    for (Database.Error err : sr.getErrors()){
                        saveErrorMsg = err.getMessage();
                        List<String> affectedFields = err.getFields();
                        if (affectedFields != null && affectedFields.size() > 0) saveErrorMsg += (saveErrorMsg.endsWith('.') ? '' : '.') + ' Affected fields: ' + String.join(affectedFields, ', ');
                        break;
                    }
                }
            }

            SoftValidationRuleHandler.isMessageSave = false;

            response = new AuraHelper.Response(String.isBlank(saveErrorMsg), saveErrorMsg);
        }
        catch(Exception ex){
            response = new AuraHelper.Response(ex);
        }

        return response;
    }
}