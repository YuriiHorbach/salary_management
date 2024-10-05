// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import { Application } from "@hotwired/stimulus";
import SalaryController from "../controllers/salary_controller";

const application = Application.start();
application.register("salary", SalaryController);
