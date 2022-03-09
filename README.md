# Intro

This is just a test setup to document how to get CloudWatch metrics for a Java application

```
vagrant up
vagrant ssh
# tmux
/home/vagrant/nifi-1.15.3/bin/nifi.sh run
aws configure --profile AmazonCloudWatchAgent
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -s -m onPremise -c file:/vagrant/cwagent-config.json
```

# Apache NiFi configuration

`vagrant provision` will install Apache NiFi at `/home/vagrant/nifi-1.15.3`

The `/home/vagrant/nifi-1.15.3/conf/bootstrap.conf` is overwritten with `./bootstrap.conf` in this repo. The only change is to add `jmx_exporter` which adds a javaagent that makes the NiFi process to expose a prometheus http endpoint at 127.0.0.1:9404 that translates the JMX MBeans to Prometheus metrics.


This is just to have an example of java app exposing prometheus endpoint with JVM metrics , so that we can publish those to CloudWatch.

To start nifi:

```
vagrant ssh
# tmux
/home/vagrant/nifi-1.15.3/bin/nifi.sh run
```

Then you can query from the guest or the host (because port forward for 9404 is setup in the `Vagrantfile`):

```
curl localhost:9404 | grep java_lang
# HELP java_lang_operatingsystem_freephysicalmemorysize FreePhysicalMemorySize (java.lang<type=OperatingSystem><>FreePhysicalMemorySize)
# TYPE java_lang_operatingsystem_freephysicalmemorysize gauge
java_lang_operatingsystem_freephysicalmemorysize 7.3805824E7
# HELP java_lang_memory_heapmemoryusage_committed java.lang.management.MemoryUsage (java.lang<type=Memory><HeapMemoryUsage>committed)
# TYPE java_lang_memory_heapmemoryusage_committed gauge
java_lang_memory_heapmemoryusage_committed 5.18979584E8
# HELP java_lang_garbagecollector_collectiontime_marksweepcompact_total CollectionTime (java.lang<name=MarkSweepCompact, type=GarbageCollector><>CollectionTime)
# TYPE java_lang_garbagecollector_collectiontime_marksweepcompact_total counter
java_lang_garbagecollector_collectiontime_marksweepcompact 0.0
# HELP java_lang_threading_threadcount ThreadCount (java.lang<type=Threading><>ThreadCount)
# TYPE java_lang_threading_threadcount gauge
java_lang_threading_threadcount 15.0
# HELP java_lang_operatingsystem_freeswapspacesize FreeSwapSpaceSize (java.lang<type=OperatingSystem><>FreeSwapSpaceSize)
# TYPE java_lang_operatingsystem_freeswapspacesize gauge
java_lang_operatingsystem_freeswapspacesize 1.009762304E9
# HELP java_lang_memory_heapmemoryusage_used java.lang.management.MemoryUsage (java.lang<type=Memory><HeapMemoryUsage>used)
# TYPE java_lang_memory_heapmemoryusage_used gauge
java_lang_memory_heapmemoryusage_used 9.625796E7
# HELP java_lang_operatingsystem_maxfiledescriptorcount MaxFileDescriptorCount (java.lang<type=OperatingSystem><>MaxFileDescriptorCount)
# TYPE java_lang_operatingsystem_maxfiledescriptorcount gauge
java_lang_operatingsystem_maxfiledescriptorcount 1048576.0
# HELP java_lang_threading_daemonthreadcount DaemonThreadCount (java.lang<type=Threading><>DaemonThreadCount)
# TYPE java_lang_threading_daemonthreadcount gauge
java_lang_threading_daemonthreadcount 14.0
# HELP java_lang_garbagecollector_collectiontime_copy_total CollectionTime (java.lang<name=Copy, type=GarbageCollector><>CollectionTime)
# TYPE java_lang_garbagecollector_collectiontime_copy_total counter
java_lang_garbagecollector_collectiontime_copy 48.0
# HELP java_lang_operatingsystem_openfiledescriptorcount OpenFileDescriptorCount (java.lang<type=OperatingSystem><>OpenFileDescriptorCount)
# TYPE java_lang_operatingsystem_openfiledescriptorcount gauge
java_lang_operatingsystem_openfiledescriptorcount 172.0
# HELP java_lang_operatingsystem_committedvirtualmemorysize CommittedVirtualMemorySize (java.lang<type=OperatingSystem><>CommittedVirtualMemorySize)
# TYPE java_lang_operatingsystem_committedvirtualmemorysize gauge
java_lang_operatingsystem_committedvirtualmemorysize 2.677936128E9
# HELP java_lang_classloading_loadedclasscount LoadedClassCount (java.lang<type=ClassLoading><>LoadedClassCount)
# TYPE java_lang_classloading_loadedclasscount gauge
java_lang_classloading_loadedclasscount 3213.0
```

These prometheus metrics are the ones that we will publish in CloudWatch using the amazon-cloudwatch-agent (cwagent)

Those metrics are the ones supported by CloudWatch Application Insights. See [Supported logs and metrics > Java ][1]. That is the point of the `./jmx_exported_config.yaml` to select just the metrics that are supported and rename some of the metrics to comply with the naming in that list [1].


# Create AWS Profile AmazonCloudWatchAgent in the vagrant vm
vagrant ssh

```
aws configure set profile.AmazonCloudWatchAgent.aws_access_key_id xxxxx
aws configure set profile.AmazonCloudWatchAgent.aws_secret_access_key xxxxx
aws configure set profile.AmazonCloudWatchAgent.aws_session_token xxxxx
aws configure set profile.AmazonCloudWatchAgent.region eu-west-1
aws configure set profile.AmazonCloudWatchAgent.format json
aws --profile AmazonCloudWatchAgent sts get-caller-identity
```



# Modify /opt/aws/amazon-cloudwatch-agent/etc/common-config.toml to point to the .aws/credentials file
/opt/aws/amazon-cloudwatch-agent/etc/common-config.toml
```
[credentials]
   shared_credential_profile = "AmazonCloudWatchAgent"
   shared_credential_file = "/home/vagrant/.aws/credentials"
```

`vagrant provision` does copy the `./common-config.toml` in this repo to the `/opt/aws/amazon-cloudwatch-agent/etc/common-config.toml` on the vagrant guest.

Remember that you need to create the `/home/vagrant/.aws/credentials` with `aws configure --profile AmazonCloudWatchAgent`.

# start amazon-cloudwatch-agent

The `./cwagent-config.json` file is the input configuration for the agent
  * [Prometheus metrics collection in cwagent][3]
  * The part about `.logs.metrics_collected.prometheus` is a bit underdocumented. Important concepts for me
     * The `.logs.metric_collected.prometheus.emf_processor` section control the  contents of `.CloudWatchMetrics` in the resulting JSON records that will appear in the CloudWatch log group/log stream. See  [EMF specification][4] to get an understanding of contents and purpose of `.CloudWatchMetrics`.
     * The way prometheus metrics is by using the Embedded Metric Format described in [7]. So it really uses PutLogEvents like if was a log file, the log events have a special format `json/emf` , when CloudWatch ingests those "logs" it will also create metrics for them.
     * `.logs.metrics_collected.prometheus.emf_processor.metric_unit` SHOULD contain the CloudWatch Unit (see [Units][6] and[MetricDatum][5]) for each metric. If you want to see the right units in the charts in CloudWatch. You can't use regexes in here so you have to manually put all of them.
     * `.logs.metrics_collected.prometheus.emf_processor.metric_declaration` : The metrics that matches the declaration here are sent to CloudWatch

The following command will generate `/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.toml` file from the input configuration `./cwagent-config.json` on this repo:

    sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -s -m onPremise -c file:/vagrant/cwagent-config.json

The `-s` options means restart.

    sudo systemctl status amazon-cloudwatch-agent.service


Or use `/vagrant/reconfigure_cwagent.sh`

Look at the logs

    tail -f /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log


Now the cloudwatch agent is running and doing:

* scraping the `http://localhost:9404` for prometheus metrics periodically
* will relabel those metrics, dropping all metrics except `java_lang_*`
* set the actual CloudWatch unit (Bytes, Milliseconds, etc) for each prometheus metric
* set the CloudWatch dimension for each prometheus metric


The metrics are sent to a CloudWatch log group / log stream and you can see them as JSON records if you open that logstream in the CloudWatch console. See an example in the [Troubleshooting section](#record), you should be seeing a `.CloudMetrics` on each record along with a key per metric plus additional keys for `instance`, etc.


# Troubleshooting

In cloudwatch console look at Logs > Log group > Log stream and you should  see the prometheus events there.

Check that you are sending the CloudWatch to the right region (it's set on the `cwagent-config.json` file)

If you see the log stream in CloudWatch but you don't see any corresponding CloudWatch Metric for them, check if you see a key `CloudWatchMetrics` on the the event, because that is what controls how that record becomes a metric (which namespace, dimensions and unit the metric should have). If it's not present then you made a mistake in the `cwagent-config.json` , probably at  `.logs.metrics_collected.prometheus.emf_processor`.



## <a name="record"></a>Example record in CloudWatch log stream:


```
{
    "CloudWatchMetrics": [
        {
            "Metrics": [
                {
                    "Unit": "Count",
                    "Name": "java_lang_threading_daemonthreadcount"
                },
                {
                    "Unit": "Count",
                    "Name": "java_lang_operatingsystem_openfiledescriptorcount"
                },
                {
                    "Unit": "Count",
                    "Name": "java_lang_threading_threadcount"
                },
                {
                    "Unit": "Bytes",
                    "Name": "java_lang_operatingsystem_freeswapspacesize"
                },
                {
                    "Unit": "Count",
                    "Name": "java_lang_classloading_loadedclasscount"
                },
                {
                    "Unit": "Bytes",
                    "Name": "java_lang_memory_heapmemoryusage_used"
                },
                {
                    "Unit": "Count",
                    "Name": "java_lang_operatingsystem_maxfiledescriptorcount"
                },
                {
                    "Unit": "Bytes",
                    "Name": "java_lang_operatingsystem_freephysicalmemorysize"
                },
                {
                    "Unit": "Bytes",
                    "Name": "java_lang_memory_heapmemoryusage_committed"
                },
                {
                    "Unit": "Bytes",
                    "Name": "java_lang_operatingsystem_committedvirtualmemorysize"
                }
            ],
            "Dimensions": [
                [
                    "instance"
                ]
            ],
            "Namespace": "CWAgent-Prometheus"
        }
    ],
    "ClusterName": "rubelagu-cluster-test",
    "Timestamp": "1646774063396",
    "Version": "0",
    "application": "nifi",
    "instance": "xxxxxxx",
    "java_lang_classloading_loadedclasscount": 13504,
    "java_lang_memory_heapmemoryusage_committed": 518979584,
    "java_lang_memory_heapmemoryusage_used": 285357688,
    "java_lang_operatingsystem_committedvirtualmemorysize": 2929106944,
    "java_lang_operatingsystem_freephysicalmemorysize": 76201984,
    "java_lang_operatingsystem_freeswapspacesize": 927461376,
    "java_lang_operatingsystem_maxfiledescriptorcount": 1048576,
    "java_lang_operatingsystem_openfiledescriptorcount": 3466,
    "java_lang_threading_daemonthreadcount": 35,
    "java_lang_threading_threadcount": 70,
    "job": "nifi-rubelagu-test",
    "os": "linux",
    "prom_metric_type": "gauge"
}
```

# References

* https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Agent-common-scenarios.html
* [Amazon CloudWatch Documentation](https://docs.aws.amazon.com/cloudwatch/index.html)
* [CloudWatch User Guide](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/WhatIsCloudWatch.html)
* [CloudWatch Applications Insights > Supported java metrics][1]
  * [amazon-cloudwatch-agent in GitHub](https://github.com/aws/amazon-cloudwatch-agent)
  * [Collecting metrics and logs from Amazon EC2 instances and on-premises servers with the CloudWatch Agent][2]
    * [Manually create or edit the CloudWatch agent configuration file](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Agent-Configuration-File-Details.html)
      * [Set up and configure Prometheus metrics collection on Amazon EC2 instances][3]
  * [Ingesting high-cardinality logs and generating metrics with CloudWatch embedded metric format][7]
    * [Manually generating embedded metric format logs (emf)](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Embedded_Metric_Format_Manual.html)
      * [Specification: Embedded metric format](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Embedded_Metric_Format_Specification.html)
  *



[1]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/appinsights-metrics-java.html "CloudWatch Applications Insights > Supported java metrics"
[2]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Install-CloudWatch-Agent.html "Collect metrics and logs with the CloudWatch agent"
[3]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Agent-PrometheusEC2.html "Setup and ocnfigure Prometheus metrics collection with cwagent"
[4]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Embedded_Metric_Format_Specification.html "Specification: Embedded metric format"
[5]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/APIReference/API_MetricDatum.html "CloudWatch MetricDatum"
[6]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/cloudwatch_concepts.html#Unit "CloudWatch concepts > Units"
[7]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Embedded_Metric_Format.html "Ingesting high-cardinality logs and generating metrics with CloudWatch embedded metric format"