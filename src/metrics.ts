import express from 'express';
import { Application, Request, Response } from 'express';
import { getDatabase } from './database';

const app: Application = express();
const port = process.env.METRICS_PORT || 9190;

const query = { status: 'waiting' };
const getJobMetrics = async (
  res: Response
): Promise<void> => {
  const numOfJobs = await getDatabase()
    .collection('thumbnailJob')
    .countDocuments(query);
  const metricString =  'num_of_requests_in_waiting ' + numOfJobs
  res.status(200).send(metricString );

}

app.get('/metrics', (_: Request, res: Response) => {
  getJobMetrics(res)
});

app.listen(port, () => console.log(`Server is listening on port ${port}`));
