global class PopulateCaseTimeOpenJob implements Schedulable {
   global void execute(SchedulableContext SC) {
      populateCaseTimeOpenBatch batch = new populateCaseTimeOpenBatch(); 
	  Database.executeBatch(batch, 10);       
   }
}