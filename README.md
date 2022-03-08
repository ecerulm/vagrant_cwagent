# Intro


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


# Troubleshooting 

In cloudwatch console look at Logs > Log group > Log stream and you should  see the prometheus events there. 

Check that you are sending the CloudWatch to the right region (it's set on the `cwagent-config.json` file)

If you see the log stream in CloudWatch but you don't see any corresponding CloudWatch Metric for them, check if you see a key `CloudWatchMetrics` on the the event, because that is what controls how that record becomes a metric (which namespace, dimensions and unit the metric should have). If it's not present then you made a mistake in the `cwagent-config.json` , probably at  `.logs.metrics_collected.prometheus.emf_processor`. 



Example record in CloudWatch log stream: 

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
