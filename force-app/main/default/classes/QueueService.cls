/******************************************************************************
// Summary:         The class helper to execute other apex classes in SF queue mode
// Test Class:      QueueServiceTest

// Modification Log: (Name - Change Summary - Initial)
====================
Roman Bulgakov - 05/09/2024 - created
*******************************************************************************/

public without sharing class QueueService implements System.Queueable, Database.AllowsCallouts
{
    public static void start(String key, Object data, String handlerName) {
        if(Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
            System.enqueueJob(new QueueService(key, data, handlerName));
        }else {
            SchedulerService.start(key, data, handlerName);
        }
    }

    /******************** QUEUEABLE SECTION ********************/

    private String key;
    private Object data;
    private String handlerName;

    public QueueService() {}
    public QueueService(String key, Object data, String handlerName) {
        this.key = key;
        this.data = data;
        this.handlerName = handlerName;
    }

    public void execute(QueueableContext context) {
        Callable instance = (Callable)Type.forName(handlerName).newInstance();
        instance.call(key, (data instanceof Map<String, Object> ? (Map<String,Object>)data : new Map<String,Object>{'data' => data}));
    }
}