/******************************************************************************
// Summary:         The class helper to schedule execution other apex classes 
// Test Class:      SchedulerServiceTest

// Modification Log: (Name - Change Summary - Initial)
====================
Roman Bulgakov - 05/09/2024 - created
*******************************************************************************/

public without sharing class SchedulerService implements Schedulable
{
    public static void start(String key, Object data, String handlerName) {
        start(key, data, handlerName, 2);
    }

    public static void start(String key, Object data, String handlerName, Integer gap) {
        System.schedule('Scheduler Service (' + String.valueOf(DateTime.now().getTime()) + ')', DateTime.now().addSeconds(gap).format('s m H d M ? yyyy'), new SchedulerService(key, data, handlerName));
    }
    
    private String key;
    private Object data;
    private String handlerName;

    public SchedulerService(){}
    public SchedulerService(String key, Object data, String handlerName) {
        this.key = key;
        this.data = data;
        this.handlerName = handlerName;
    }

    public void execute(SchedulableContext ctx) {
        QueueService.start(key, data, handlerName);
	}
}