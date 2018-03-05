
using System;
using System.Configuration;
using Microsoft.AnalysisServices.Tabular;
using System.Net;

public static async Task<HttpResponseMessage> Run(HttpRequestMessage req, TraceWriter log)
{
    log.Info("C# HTTP trigger function processed a request.");

    // parse query parameter
    string status = req.GetQueryNameValuePairs()
        .FirstOrDefault(q => string.Compare(q.Key, "status", true) == 0)
        .Value;

    if (status == null)
    {
        // Get request body
        dynamic data = await req.Content.ReadAsAsync<object>();
        status = data?.status;
    }
    if (status == "execute")
    {log.Info($"C# trigger function started at: {DateTime.Now}");  
    try
            {
                Microsoft.AnalysisServices.Tabular.Server asSrv = new Microsoft.AnalysisServices.Tabular.Server();
                var connStr = ConfigurationManager.ConnectionStrings["AASProductModel"].ConnectionString;
                asSrv.Connect(connStr);
                Database db = asSrv.Databases["azureadventureworks"];
                Model m = db.Model;
                //db.Model.RequestRefresh(RefreshType.Full);     // Mark the model for refresh
                m.RequestRefresh(RefreshType.Full);     // Mark the model for refresh
                //m.Tables["Date"].RequestRefresh(RefreshType.Full);     // Mark only one table for refresh
                db.Model.SaveChanges();     //commit  which will execute the refresh
                asSrv.Disconnect();
            }
            catch (Exception e)
            {
                log.Info($"C# trigger function exception: {e.ToString()}");
            }
    log.Info($"C# trigger function finished at: {DateTime.Now}"); 
    }
    return status == "execute"
        ?req.CreateResponse(HttpStatusCode.OK, "Successfully Processed Tabular Model ") 
        :req.CreateResponse(HttpStatusCode.BadRequest, "Please pass a status on the query string or in the request body");
        

}
