public class ctrlGanttChart {
  @RemoteAction
  public static Contact[] getResources() {
    return [SELECT Id, Name, Email FROM Contact 
            WHERE RecordType.Name = 'Resource' AND Status__c = 'Active' AND External_Resource__c = FALSE
            ORDER BY Name];
  }
  
  @RemoteAction
  public static SFDC_Assignment__c[] getAssignments( String resource ) {
    return Database.query('SELECT Name, Client_Rate__c, Start_Date__c, End_Date__c, Number_of_Hours__c, '
      + 'Projects__r.Id, Projects__r.Name, Projects__r.Start_Date__c, Projects__r.End_Date__c '
      + 'FROM SFDC_Assignment__c WHERE Resource__c = \'' + resource + '\' AND Projects__r.Name <> \'Doextra Internal\' AND '
      + 'End_Date__c <> NULL AND End_Date__c > TODAY');
  }
}