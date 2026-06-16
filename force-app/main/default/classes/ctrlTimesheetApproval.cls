public class ctrlTimesheetApproval {
    public Id tsId {get;set;}
    public List<Timesheet__c> getTis()
    {
        List<Timesheet__c> ts;
        ts = [SELECT ID FROM Timesheet__c WHERE Id =: tsId];
        return ts;
    }    
    public List<SFDC_Timecard__c> gettCards()
    {
        List<SFDC_Timecard__c> TCLine;
        TCLine = [
            SELECT 
            Account__c, 
            Date__c, 
            Hours__c, 
            Project__c, 
            Description_of_Work__c
            FROM 
            SFDC_Timecard__c 
            WHERE 
            Timesheet__c =: tsId
            order by Date__c asc
        ];
        return TCLine;
    }
    
    public decimal getTotal(){
        Decimal total=0;
        
        for(SFDC_Timecard__c tsl :[SELECT Id, Hours__c FROM SFDC_Timecard__c WHERE Timesheet__c =: tsId]){
            total += tsl.Hours__c;
        }
        return total;
    }
    
}