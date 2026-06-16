global class ProjectCounterSchedule implements schedulable{
    global void execute(SchedulableContext sc){
        ProjectCounter pc = new ProjectCounter();
        database.executebatch(pc);
    }
}