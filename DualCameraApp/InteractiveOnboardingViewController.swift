//
//  InteractiveOnboardingViewController.swift
//  DualCameraApp
//
//  Interactive onboarding experience showcasing dual camera capabilities with modern iOS 18+ UI
//

import UIKit

class InteractiveOnboardingViewController: UIViewController {
    
    // MARK: - Properties
    
    private var currentPage = 0
    private let totalPages = 5
    
    // UI Components
    private let backgroundView = UIView()
    private let pageViewController = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
    private let pageControl = UIPageControl()
    private let skipButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    private let getStartedButton = UIButton(type: .system)
    private let progressView = UIProgressView(progressViewStyle: .default)
    
    // Material containers
    private let topContainer = EnhancedGlassmorphismView(material: .ultraThin, vibrancy: .primary)
    private let bottomContainer = EnhancedGlassmorphismView(material: .systemThickMaterial, vibrancy: .primary)
    
    // Onboarding completion handler
    var onOnboardingCompleted: (() -> Void)?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupPageViewController()
        setupConstraints()
        updateUIForCurrentPage()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Hide navigation bar for full-screen experience
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        // Setup background with gradient
        setupBackground()
        
        // Setup material containers
        setupMaterialContainers()
        
        // Setup page control
        setupPageControl()
        
        // Setup buttons
        setupButtons()
        
        // Setup progress view
        setupProgressView()
    }
    
    private func setupBackground() {
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundView)
        
        // Create dynamic gradient background
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            EnhancedColorSystem.DynamicColor.background.color.cgColor,
            EnhancedColorSystem.DynamicColor.surface.color.cgColor,
            EnhancedColorSystem.DynamicColor.primaryContainer.color.withAlphaComponent(0.3).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        backgroundView.layer.addSublayer(gradientLayer)
        
        // Store gradient layer for layout updates
        backgroundView.layer.name = "gradientLayer"
    }
    
    private func setupMaterialContainers() {
        // Top container for page control and skip button
        topContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topContainer)
        
        // Bottom container for buttons and progress
        bottomContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomContainer)
        
        // Add subviews to containers
        topContainer.contentView.addSubview(pageControl)
        topContainer.contentView.addSubview(skipButton)
        
        bottomContainer.contentView.addSubview(nextButton)
        bottomContainer.contentView.addSubview(getStartedButton)
        bottomContainer.contentView.addSubview(progressView)
    }
    
    private func setupPageControl() {
        pageControl.numberOfPages = totalPages
        pageControl.currentPage = 0
        pageControl.pageIndicatorTintColor = EnhancedColorSystem.DynamicColor.outlineVariant.color
        pageControl.currentPageIndicatorTintColor = EnhancedColorSystem.DynamicColor.primary.color
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        
        pageControl.addTarget(self, action: #selector(pageControlChanged), for: .valueChanged)
    }
    
    private func setupButtons() {
        // Skip button
        skipButton.setTitle("Skip", for: .normal)
        skipButton.setTitleColor(EnhancedColorSystem.DynamicColor.primary.color, for: .normal)
        skipButton.titleLabel?.font = DesignSystem.Typography.callout.font
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        skipButton.addTarget(self, action: #selector(skipButtonTapped), for: .touchUpInside)
        
        // Next button
        nextButton.setTitle("Next", for: .normal)
        nextButton.setTitleColor(EnhancedColorSystem.DynamicColor.onPrimary.color, for: .normal)
        nextButton.backgroundColor = EnhancedColorSystem.DynamicColor.primary.color
        nextButton.titleLabel?.font = DesignSystem.Typography.callout.font
        nextButton.layer.cornerRadius = 24
        nextButton.layer.cornerCurve = .continuous
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)
        
        // Get Started button
        getStartedButton.setTitle("Get Started", for: .normal)
        getStartedButton.setTitleColor(EnhancedColorSystem.DynamicColor.onPrimary.color, for: .normal)
        getStartedButton.backgroundColor = EnhancedColorSystem.DynamicColor.primary.color
        getStartedButton.titleLabel?.font = DesignSystem.Typography.callout.font
        getStartedButton.layer.cornerRadius = 24
        getStartedButton.layer.cornerCurve = .continuous
        getStartedButton.translatesAutoresizingMaskIntoConstraints = false
        getStartedButton.addTarget(self, action: #selector(getStartedButtonTapped), for: .touchUpInside)
        getStartedButton.isHidden = true
    }
    
    private func setupProgressView() {
        progressView.progressTintColor = EnhancedColorSystem.DynamicColor.primary.color
        progressView.trackTintColor = EnhancedColorSystem.DynamicColor.surfaceVariant.color
        progressView.layer.cornerRadius = 2
        progressView.clipsToBounds = true
        progressView.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupPageViewController() {
        pageViewController.dataSource = self
        pageViewController.delegate = self
        
        // Set initial page
        if let firstPage = createOnboardingPage(at: 0) {
            pageViewController.setViewControllers([firstPage], direction: .forward, animated: false)
        }
        
        // Add page view controller as child
        addChild(pageViewController)
        view.addSubview(pageViewController.view)
        pageViewController.didMove(toParent: self)
        
        pageViewController.view.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Background
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Page view controller
            pageViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            pageViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Top container
            topContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: DesignSystem.Spacing.lg.value),
            topContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignSystem.Spacing.md.value),
            topContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignSystem.Spacing.md.value),
            topContainer.heightAnchor.constraint(equalToConstant: 60),
            
            // Bottom container
            bottomContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -DesignSystem.Spacing.lg.value),
            bottomContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignSystem.Spacing.md.value),
            bottomContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignSystem.Spacing.md.value),
            bottomContainer.heightAnchor.constraint(equalToConstant: 120),
            
            // Page control
            pageControl.centerXAnchor.constraint(equalTo: topContainer.contentView.centerXAnchor),
            pageControl.centerYAnchor.constraint(equalTo: topContainer.contentView.centerYAnchor),
            
            // Skip button
            skipButton.trailingAnchor.constraint(equalTo: topContainer.contentView.trailingAnchor),
            skipButton.centerYAnchor.constraint(equalTo: topContainer.contentView.centerYAnchor),
            
            // Progress view
            progressView.topAnchor.constraint(equalTo: bottomContainer.contentView.topAnchor, constant: DesignSystem.Spacing.md.value),
            progressView.leadingAnchor.constraint(equalTo: bottomContainer.contentView.leadingAnchor, constant: DesignSystem.Spacing.md.value),
            progressView.trailingAnchor.constraint(equalTo: bottomContainer.contentView.trailingAnchor, constant: -DesignSystem.Spacing.md.value),
            progressView.heightAnchor.constraint(equalToConstant: 4),
            
            // Next button
            nextButton.bottomAnchor.constraint(equalTo: bottomContainer.contentView.bottomAnchor, constant: -DesignSystem.Spacing.md.value),
            nextButton.trailingAnchor.constraint(equalTo: bottomContainer.contentView.trailingAnchor, constant: -DesignSystem.Spacing.md.value),
            nextButton.widthAnchor.constraint(equalToConstant: 100),
            nextButton.heightAnchor.constraint(equalToConstant: 48),
            
            // Get Started button
            getStartedButton.bottomAnchor.constraint(equalTo: bottomContainer.contentView.bottomAnchor, constant: -DesignSystem.Spacing.md.value),
            getStartedButton.centerXAnchor.constraint(equalTo: bottomContainer.contentView.centerXAnchor),
            getStartedButton.widthAnchor.constraint(equalToConstant: 160),
            getStartedButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }
    
    // MARK: - Page Creation
    
    private func createOnboardingPage(at index: Int) -> OnboardingPageViewController? {
        guard index < totalPages else { return nil }
        
        let page = OnboardingPageViewController()
        page.pageIndex = index
        
        switch index {
        case 0:
            page.configure(
                title: "Welcome to Dual Camera",
                subtitle: "Experience the power of recording with both front and back cameras simultaneously",
                imageName: "dual.camera.icon",
                animationType: .fadeIn
            )
        case 1:
            page.configure(
                title: "Dual Recording",
                subtitle: "Capture moments from multiple perspectives at the same time",
                imageName: "dual.recording.icon",
                animationType: .slideIn
            )
        case 2:
            page.configure(
                title: "Advanced Controls",
                subtitle: "Fine-tune focus, exposure, and zoom for professional results",
                imageName: "advanced.controls.icon",
                animationType: .scaleIn
            )
        case 3:
            page.configure(
                title: "Triple Output",
                subtitle: "Save front, back, and combined videos for maximum flexibility",
                imageName: "triple.output.icon",
                animationType: .bounceIn
            )
        case 4:
            page.configure(
                title: "Ready to Create",
                subtitle: "Start capturing your stories with the power of dual cameras",
                imageName: "ready.to.create.icon",
                animationType: .zoomIn
            )
        default:
            return nil
        }
        
        return page
    }
    
    // MARK: - UI Updates
    
    private func updateUIForCurrentPage() {
        // Update page control
        pageControl.currentPage = currentPage
        
        // Update progress
        let progress = Float(currentPage + 1) / Float(totalPages)
        progressView.setProgress(progress, animated: true)
        
        // Update buttons
        let isLastPage = currentPage == totalPages - 1
        
        UIView.animate(withDuration: 0.3) {
            self.nextButton.isHidden = isLastPage
            self.getStartedButton.isHidden = !isLastPage
        }
        
        // Update skip button visibility
        skipButton.isHidden = isLastPage
        
        // Add haptic feedback
        HapticFeedbackManager.shared.selectionChanged()
    }
    
    // MARK: - Actions
    
    @objc private func pageControlChanged() {
        let targetPage = pageControl.currentPage
        let direction: UIPageViewController.NavigationDirection = targetPage > currentPage ? .forward : .reverse
        
        if let targetVC = createOnboardingPage(at: targetPage) {
            pageViewController.setViewControllers([targetVC], direction: direction, animated: true) { [weak self] _ in
                self?.currentPage = targetPage
                self?.updateUIForCurrentPage()
            }
        }
    }
    
    @objc private func skipButtonTapped() {
        if let lastPage = createOnboardingPage(at: totalPages - 1) {
            pageViewController.setViewControllers([lastPage], direction: .forward, animated: true) { [weak self] _ in
                guard let self = self else { return }
                self.currentPage = self.totalPages - 1
                self.updateUIForCurrentPage()
            }
        }
        
        HapticFeedbackManager.shared.lightImpact()
    }
    
    @objc private func nextButtonTapped() {
        guard currentPage < totalPages - 1 else { return }
        
        let nextPage = currentPage + 1
        if let nextVC = createOnboardingPage(at: nextPage) {
            pageViewController.setViewControllers([nextVC], direction: .forward, animated: true) { [weak self] _ in
                self?.currentPage = nextPage
                self?.updateUIForCurrentPage()
            }
        }
        
        HapticFeedbackManager.shared.mediumImpact()
    }
    
    @objc private func getStartedButtonTapped() {
        // Animate button press
        UIView.animate(withDuration: 0.1, animations: {
            self.getStartedButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.getStartedButton.transform = .identity
            }
        }
        
        HapticFeedbackManager.shared.success()
        
        // Complete onboarding
        completeOnboarding()
    }
    
    private func completeOnboarding() {
        // Save onboarding completion status
        UserDefaults.standard.set(true, forKey: "OnboardingCompleted")
        
        // Call completion handler
        onOnboardingCompleted?()
        
        // Dismiss with animation
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0
        }) { _ in
            self.dismiss(animated: false)
        }
    }
    
    // MARK: - Layout
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Update gradient layer frame
        if let gradientLayer = backgroundView.layer.sublayers?.first as? CAGradientLayer {
            gradientLayer.frame = backgroundView.bounds
        }
    }
}

// MARK: - UIPageViewControllerDataSource

extension InteractiveOnboardingViewController: UIPageViewControllerDataSource {
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let pageVC = viewController as? OnboardingPageViewController,
              let pageIndex = pageVC.pageIndex,
              pageIndex > 0 else {
            return nil
        }
        
        return createOnboardingPage(at: pageIndex - 1)
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let pageVC = viewController as? OnboardingPageViewController,
              let pageIndex = pageVC.pageIndex,
              pageIndex < totalPages - 1 else {
            return nil
        }
        
        return createOnboardingPage(at: pageIndex + 1)
    }
}

// MARK: - UIPageViewControllerDelegate

extension InteractiveOnboardingViewController: UIPageViewControllerDelegate {
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if completed,
           let currentVC = pageViewController.viewControllers?.first as? OnboardingPageViewController,
           let pageIndex = currentVC.pageIndex {
            currentPage = pageIndex
            updateUIForCurrentPage()
        }
    }
}

// MARK: - Onboarding Page View Controller

class OnboardingPageViewController: UIViewController {
    
    var pageIndex: Int?
    
    private let containerView = UIView()
    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let animationContainer = UIView()
    
    private var animationType: AnimationType = .fadeIn
    
    enum AnimationType {
        case fadeIn
        case slideIn
        case scaleIn
        case bounceIn
        case zoomIn
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = .clear
        
        // Setup container
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        // Setup image view
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        animationContainer.addSubview(imageView)
        
        // Setup title label
        titleLabel.font = DesignSystem.Typography.title2.font
        titleLabel.textColor = EnhancedColorSystem.DynamicColor.onBackground.color
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
        
        // Setup subtitle label
        subtitleLabel.font = DesignSystem.Typography.body.font
        subtitleLabel.textColor = EnhancedColorSystem.DynamicColor.onSurface.color
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(subtitleLabel)
        
        // Setup animation container
        animationContainer.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(animationContainer)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: DesignSystem.Spacing.lg.value),
            containerView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -DesignSystem.Spacing.lg.value),
            
            animationContainer.topAnchor.constraint(equalTo: containerView.topAnchor),
            animationContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            animationContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            animationContainer.heightAnchor.constraint(equalToConstant: 200),
            
            imageView.centerXAnchor.constraint(equalTo: animationContainer.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: animationContainer.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 150),
            imageView.heightAnchor.constraint(equalToConstant: 150),
            
            titleLabel.topAnchor.constraint(equalTo: animationContainer.bottomAnchor, constant: DesignSystem.Spacing.xl.value),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DesignSystem.Spacing.md.value),
            subtitleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
    }
    
    func configure(title: String, subtitle: String, imageName: String, animationType: AnimationType) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        imageView.image = UIImage(named: imageName)
        self.animationType = animationType
        
        // Apply initial state for animation
        applyInitialStateForAnimation()
    }
    
    private func applyInitialStateForAnimation() {
        switch animationType {
        case .fadeIn:
            animationContainer.alpha = 0
        case .slideIn:
            animationContainer.transform = CGAffineTransform(translationX: 0, y: 50)
        case .scaleIn:
            animationContainer.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        case .bounceIn:
            animationContainer.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
        case .zoomIn:
            animationContainer.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
            animationContainer.alpha = 0
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Perform entrance animation
        performEntranceAnimation()
    }
    
    private func performEntranceAnimation() {
        UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: [.curveEaseOut]) {
            switch self.animationType {
            case .fadeIn:
                self.animationContainer.alpha = 1
            case .slideIn:
                self.animationContainer.transform = .identity
            case .scaleIn:
                self.animationContainer.transform = .identity
            case .bounceIn:
                self.animationContainer.transform = .identity
            case .zoomIn:
                self.animationContainer.transform = .identity
                self.animationContainer.alpha = 1
            }
        }
    }
}