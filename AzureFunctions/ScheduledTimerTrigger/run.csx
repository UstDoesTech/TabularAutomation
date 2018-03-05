

using System;
using System.Configuration;
using Microsoft.AnalysisServices.Tabular;

public static void Run(TimerInfo myTimer, TraceWriter log)

{
    log.Info($"C# Timer trigger function started at: {DateTime.Now}");  
    try
            {
                Microsoft.AnalysisServices.Tabular.Server asSrv = new Microsoft.AnalysisServices.Tabular.Server();
                var connStr = ConfigurationManager.ConnectionStrings["AASTabular"].ConnectionString;
                asSrv.Connect(connStr);
                Database db = asSrv.Databases["azureadventureworks"];
                Model m = db.Model;
                //db.Model.RequestRefresh(RefreshType.Full);     // Mark the model for refresh
                m.RequestRefresh(RefreshType.Full);     // Mark the model for refresh
                //m.Tables["Date"].RequestRefresh(RefreshType.Full);     // Mark only one table for refresh
                db.Model.SaveChanges();     //commit  which will execute the refresh
                asSrv.Disconnect();
            }
    catch (Exception e)
            {
                log.Info($"C# Timer trigger function exception: {e.ToString()}");
            }
    log.Info($"C# Timer trigger function finished at: {DateTime.Now}"); 
}