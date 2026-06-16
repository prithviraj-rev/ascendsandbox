trigger AccountTrigger on Account (before update, after insert, after update) {
    if(Trigger.isBefore && Trigger.isUpdate){
        AccountHandler.getAccountTeam(trigger.new, trigger.oldmap);
    }
    if(Trigger.isAfter && Trigger.isInsert){
        AccountHandler.insertAccountTeam(trigger.new, trigger.oldmap);
    }
    if(Trigger.isAfter && Trigger.isUpdate){
        AccountHandler.updateAccountTeam(trigger.newmap, trigger.oldmap);
        AccountHandler.updateCSM(trigger.new, trigger.oldmap);
    }
}