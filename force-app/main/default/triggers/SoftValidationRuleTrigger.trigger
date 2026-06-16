/******************************************************************************
// File Name:       SoftValidationRuleTrigger
// Summary:         Trigger for SoftValidationRule__c object
// Test Class:      SoftValidationRuleHandlerTest
// Created On:      08/01/2021

// Modification Log: (Name - Change Summary - Initial)
====================
Konstantin Ermolenko - 08/01/2021 - created trigger
*******************************************************************************/

trigger SoftValidationRuleTrigger on SoftValidationRule__c (before insert, after insert, before update, after update, before delete, after delete, after undelete) {
    SoftValidationRuleHandler handler = new SoftValidationRuleHandler();

    // Before Trigger
    if (Trigger.isBefore) {
        // Call the bulk before to handle any caching of data and enable bulkification
        handler.bulkBefore();

        // Iterate through the records to be deleted passing them to the handler.
        if (Trigger.isDelete) {
            for (SObject so : Trigger.old) {
                handler.beforeDelete(so);
            }
        }
        // Iterate through the records to be inserted passing them to the handler.
        else if (Trigger.isInsert) {
            for (SObject so : Trigger.new) {
                handler.beforeInsert(so);
            }
        }
        // Iterate through the records to be updated passing them to the handler.
        else if (Trigger.isUpdate) {
            for (SObject so : Trigger.old) {
                handler.beforeUpdate(so, Trigger.newMap.get(so.Id));
            }
        }
    }
    else {
        // Call the bulk after to handle any caching of data and enable bulkification
        handler.bulkAfter();

        // Iterate through the records deleted passing them to the handler.
        if (Trigger.isDelete) {
            for (SObject so : Trigger.old) {
                handler.afterDelete(so);
            }
        }
        // Iterate through the records inserted passing them to the handler.
        else if (Trigger.isInsert) {
            for (SObject so : Trigger.new) {
                handler.afterInsert(so);
            }
        }
        // Iterate through the records updated passing them to the handler.
        else if (Trigger.isUpdate) {
            for (SObject so : Trigger.old) {
                handler.afterUpdate(so, Trigger.newMap.get(so.Id));
            }
        }
        // Iterate through the records updated passing them to the handler.
        else if (Trigger.isUndelete) {
            for (SObject so : Trigger.new) {
                handler.afterUndelete(so);
            }
        }
    }

    // Perform any post processing
    handler.andFinally();
}