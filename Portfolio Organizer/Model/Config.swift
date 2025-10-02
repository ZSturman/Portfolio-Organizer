//
//  Config.swift
//  Portfolio Organizer
//
//  Created by Zachary Sturman on 9/29/25.
//

import Foundation

struct Config: Codable {
    var resource_types: [String]
    var visibility: [String:String]
    var domain_categories: [String:[String]]
    var tech_mediums: [String]
    var hardware_mediums: [String]
    var script_mediums: [String]
    var game_mediums: [String]
    var creative_genres: [String]
    var expository_topics: [String]
    var creative_story_mediums: [String]
    var creative_article_mediums: [String]

    static func `default`() -> Config {
        .init(
            resource_types: ["github","gitlab","overleaf","gdoc","gslide","pdf","markdown","video","audio","image","dataset","website","blog"],
            visibility: ["private":"Private","unlisted":"Unlisted","public":"Public","restricted":"Restricted"],
            domain_categories: ["Technology":["Software","Hardware","System"],"Creative":["Story","Game","Article","Other"],"Expository":["Article","Essay","Research","Report","Tutorial","WhitePaper"]],
            tech_mediums: ["Mobile","Desktop","Web","CLI","API","Module","Library","AR","VR"],
            hardware_mediums: ["Microcontroller","SingleBoardComputer","FPGA","PCB","Sensor","Actuator","Robotics","Wearable","IoTDevice","EmbeddedAppliance"],
            script_mediums: ["TV","Movie","Stage","Podcast","Radio","Animation","WebSeries","AudioDrama"],
            game_mediums: ["Mobile","Web","Desktop","Board","AR","VR","Card","Console"],
            creative_genres: ["Comedy","Horror","Drama","SciFi","Fantasy","Thriller","Romance","Mystery","Nonfiction","Action","Adventure","Educational","Informative","Other"],
            expository_topics: ["Biology","Mathematics","Physics","Chemistry","ComputerScience","Engineering","Economics","History","Philosophy","Psychology","Sociology","PoliticalScience","Education","Law","Medicine","EnvironmentalScience","DataScience","Art","Literature"],
            creative_story_mediums: ["Tiny","Short","Novel","Stage","TV","Movie","Podcast","Radio","Web Series","Other"],
            creative_article_mediums: ["Blog","Overleaf","Newsletter","Magazine","Documentation","Other"]
        )
    }
}
