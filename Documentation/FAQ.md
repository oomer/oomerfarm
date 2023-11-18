### FAQ

>What does oomerfarm look like? 

1. In the home

    ![image](../img/deployhome.png )

2. Road warrior spinning up cloud rentals as needed

    ![image](../img/deploycloud.png )

3. Combining home computers with hourly rentals

    ![image](../img/deploymixed.png )


>How do I download renders?
- running ***bridgeoomerfarm.sh*** connects to your private oomerfarm network. Mount the ***hub*** like any other network folder.
    -  Microsoft Explorer 
        - **//hub.oomer.org/oomerfarm/renders**  (win)
    -  MacOS Finder ( Connect to Server ) 
        - **smb://hub.oomer.org/oomerfarm/renders** 

>What is hub.oomer.org?
- hub.oomer.org resolves to the vpn ip address of your hub. I run the domain oomer.org and point hub.oomer.org to the address 10.87.0.1. You can use either but hub.oomer.org is easier to remember.

>Is oomerfarm useful for a lone artist?
- Yes, renting cloud computers by the hour is less capital cost intensive than buying another computer just to do renders. I am currently tracking a benchmark scene that renders for $0.04/frame using a rented cloud computer and $0.005-$0.01/frame in electrical costs using on-premise hardware based on similar cpu resources. 
- Renderfarm queues are a great way to explore rendering different looks.
- It can take as little as 5 minutes to add a new ***worker** so scaling from 1 to 5 render machines is a breeze.

>Is oomerfarm useful for a team of artists?
- Yes, within the oomerfarm private network, any artists can submit jobs to the renderfarm to share resources across multiple locations including multiple on-premise workers. 

>Can I use oomerfarm without the cloud?
- Yes, grab a bunch of brand new Threadrippers or 10 year old Xeon's along with a single ebay computer acting as the ***hub***, install ***Linux*** on all of them and plug in the ethernet cables and run the oomerfarm bash scripts.

>Why does oomerfarm incorporate a vpn?
- a vpn secures and simplifies your network and without it any moderately complex topology like using Google ***workers*** and a ***hub*** on Amazon and a few local ***workers*** in your basement become hard or impossible to maintain. The Nebula overlay vpn created by Slack and used for Slack infrastructure is performant and open source.


>Can I use oomerfarm on the road with a laptop and cloud render workers?
- Yes, the VPN works anywhere you have internet access to connect fully to all parts of your renderfarm. I use it daily in my car.

>Can I use a mix of computers I own and the cloud and a laptop?
- Yes, blend existing hardware and add a rental computer with the bash scripts in minutes. Manually shut down rentals after downloading rendered images from the file server. For advanced animation users, who deploy dozens of spot instances on Google, AWS or Azure, **workers** can detect idle cpu time and automatically shut down in the middle of the night whenever the renderfarm job queue is empty.

> Can I use Windows or MacOS computers as the hub or as workers?
- Maybe, while Deadline supports running on Windows , MacOS and Linux, oomerfarm limits  **workers** and **hub** to running Linux because it is already insanely complex. Read the Deadline docs to add this functionality yourself after the base oomerfarm is up and running.